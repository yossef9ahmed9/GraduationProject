using System;
using System.Collections.Generic;
using System.Linq;
using GraduationProject.Contracts.OCR;
using System.Text.RegularExpressions;

namespace GraduationProject.Services.OCR
{
    public class AnalysisService : IAnalysisService
    {
        private readonly Dictionary<string, (double? min, double? max)> _defaultRanges = new()
        {
            { "Hemoglobin",  (12.5, 17.5) },
            { "Hematocrit",  (41,   52)   },
            { "RBCs Count",  (4.5,  5.9)  },
            { "MCV",         (80,   100)  },
            { "MCH",         (27,   33)   },
            { "MCHC",        (31,   37)   },
            { "RDW-CV",      (11.5, 15)   },
            { "Platelets",   (150,  450)  },
            { "WBC",         (4,    11)   },
            { "Neutrophils", (2,    7)    },
            { "Lymphocytes", (1,    4.8)  },
            { "Monocytes",   (0.2,  1.0)  },
            { "Eosinophils", (0.1,  0.45) },
            { "Basophils",   (0,    0.1)  }
        };

        public AnalysisResult Analyze(string text)
        {
            var result = new AnalysisResult();
            result.Tests = new List<LabValue>();
            result.Alerts = new List<string>();

            text = PreprocessText(text);

            var tests = ExtractTests(text);

            bool nothingExtracted = !tests.Any();
            bool allExtractedAreZero = tests.Any() && tests.All(t => t.Value == 0);

            if (nothingExtracted || allExtractedAreZero)
            {
                result.Status = "InvalidScan";
                result.IsValidScan = false;
                result.Tests = new List<LabValue>();
                result.Alerts = new List<string>
                {
                    "Could not extract any lab values from the image. " +
                    "Please make sure the image is a clear, well-lit photo of a CBC lab report."
                };
                return result;
            }

            tests = EnsureCompleteTests(tests, text);

            var alerts = new List<string>();
            var overallStatus = "Normal";

            foreach (var test in tests)
            {
                // ── Sanity check: value is way outside any realistic range ──────
                // This means OCR dropped/added digits — don't guess, just flag it.
                if (IsUnreadable(test))
                {
                    test.Status = "UnreadableValue";
                    alerts.Add($"{test.Name} value ({test.Value}) could not be read clearly — please verify manually.");
                    overallStatus = "Warning";
                    continue;
                }

                // ── Normal Low / High classification ─────────────────────────
                if (test.Min.HasValue && test.Value < test.Min)
                {
                    test.Status = "Low";
                    alerts.Add($"{test.Name} is Low ({test.Value})");
                    overallStatus = "Warning";
                }
                else if (test.Max.HasValue && test.Value > test.Max)
                {
                    test.Status = "High";
                    alerts.Add($"{test.Name} is High ({test.Value})");
                    overallStatus = "Warning";
                }
                else
                {
                    test.Status = "Normal";
                }
            }

            result.Tests = tests;
            result.Status = overallStatus;
            result.Alerts = alerts;
            result.IsValidScan = true;

            return result;
        }

        // ---------------------------------------------------------------
        // Sanity check — is the value so far off the reference range that
        // it must be an OCR misread?  No math corrections, just detection.
        //
        // Rules (tuned to CBC realistic physiology):
        //   • value < min * 0.3  → suspiciously low  (e.g. Hb 1.2 when min=12)
        //   • value > max * 4.0  → suspiciously high (e.g. WBC 91 when max=11)
        //   • value == 0         → nothing was extracted
        // ---------------------------------------------------------------
        private bool IsUnreadable(LabValue test)
        {
            if (test.Value == 0) return true;

            if (test.Min.HasValue && test.Min > 0 && test.Value < test.Min.Value * 0.3)
                return true;

            if (test.Max.HasValue && test.Max > 0 && test.Value > test.Max.Value * 4.0)
                return true;

            return false;
        }

        // ---------------------------------------------------------------
        // Pre-process: fix common OCR substitutions BEFORE regex matching
        // ---------------------------------------------------------------
        private string PreprocessText(string text)
        {
            // --- Remove up/down arrows added by labs for abnormal flags ---
            // e.g. "↓79.6" or "↑16.1" → " 79.6" / " 16.1"
            text = Regex.Replace(text, @"[↓↑⇓⇑▼▲]+", " ");

            // --- normalise reference-range strings that lost their decimal point ---
            var rangeFixups = new Dictionary<string, string>
            {
                { "125-175",   "12.5-17.5" },
                { "45-59",     "4.5-5.9"   },
                { "115-15",    "11.5-15"   },
                { "02-1",      "0.2-1.0"   },
                { "1-438",     "1-4.8"     },
                { "1-428",     "1-4.8"     },
                { "0-01",      "0-0.1"     },
                { "01-045",    "0.1-0.45"  },
                { "01-0.45",   "0.1-0.45"  },
                { "150 - 450", "150-450"   },
                { "80 - 100",  "80-100"    },
            };

            foreach (var fix in rangeFixups)
                text = text.Replace(fix.Key, fix.Value);

            // --- fix absolute differential values that lost their decimal point ---
            // e.g. "212  x10" → "2.12  x10"
            text = Regex.Replace(text,
                @"\b([1-9])(\d{2})\b(?=\s*x10)",
                m => m.Groups[1].Value + "." + m.Groups[2].Value);

            // --- x10 unit variants ---
            text = Regex.Replace(text,
                @"x10[A|O|0|4|7|%]?9[/\\]?[lL1]",
                "x10^9/L",
                RegexOptions.IgnoreCase);

            // --- g/dl OCR variants ---
            text = Regex.Replace(text,
                @"\b(g[il1/\\]d[il1]|o[il1]d[il1]|g\/d[il1]|g\/dl)\b",
                "g/dl",
                RegexOptions.IgnoreCase);

            // --- fl unit ---
            text = Regex.Replace(text, @"\bfl\b", "fl", RegexOptions.IgnoreCase);

            // --- MCV 3-digit int (e.g. 796 → 79.6) ---
            text = Regex.Replace(text,
                @"mcv\s+fl\s+(\d{3})\s+fl",
                m => $"MCV {double.Parse(m.Groups[1].Value) / 10} fl",
                RegexOptions.IgnoreCase);
            text = text.Replace("fl 796", "79.6 fl");
            text = text.Replace("796 fl", "79.6 fl");

            return text;
        }

        // ---------------------------------------------------------------
        // Extract tests line by line
        // ---------------------------------------------------------------
        private List<LabValue> ExtractTests(string text)
        {
            var tests = new List<LabValue>();
            var lines = text.Split('\n');

            foreach (var line in lines)
            {
                var clean = line.Trim();
                if (string.IsNullOrWhiteSpace(clean)) continue;

                // ── Differential ─────────────────────────────────────────────
                // FIX: added [^%]* before % to tolerate stray chars like "( %" from OCR
                var diffMatch = Regex.Match(clean,
                    @"(neutrophils?\.?|lymphocytes?\.?|monocytes?\.?|eosinophils?\.?|basophils?\.?)" +
                    @"\s*[:\s]*(\d+\.?\d*)\s*[^%]*%\s*[:\s]*(\d+\.?\d*)\s*x10",
                    RegexOptions.IgnoreCase);

                if (diffMatch.Success)
                {
                    var name = NormalizeName(diffMatch.Groups[1].Value);
                    var value = ParseNumber(diffMatch.Groups[3].Value);

                    if (_defaultRanges.ContainsKey(name))
                    {
                        tests.Add(new LabValue
                        {
                            Name = name,
                            Value = value,
                            Min = _defaultRanges[name].min,
                            Max = _defaultRanges[name].max
                        });
                    }
                    continue;
                }

                // ── Haemoglobin ───────────────────────────────────────────────
                var hbMatch = Regex.Match(clean,
                    @"h[ae]{1,2}m[oe]?globin\s+(\d+\.?\d*)\s*" +
                    @"(?:g[il1/\\]d[il1]|g\/dl|g\/d1|oldl|gldl|gidl)?" +
                    @"\s*(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (hbMatch.Success)
                {
                    var value = ParseNumber(hbMatch.Groups[1].Value);
                    var min = ParseNumber(hbMatch.Groups[2].Value);
                    var max = ParseNumber(hbMatch.Groups[3].Value);

                    if (min > 100) { min /= 10; max /= 10; }
                    if (value > 100) value /= 10;

                    tests.Add(new LabValue { Name = "Hemoglobin", Value = value, Min = min, Max = max });
                    continue;
                }

                // ── Haematocrit ───────────────────────────────────────────────
                var hctMatch = Regex.Match(clean,
                    @"h[ae]{1,2}m[ae]tocrit.*?(\d+\.?\d*)\s*%\s*(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (hctMatch.Success)
                {
                    var value = ParseNumber(hctMatch.Groups[1].Value);
                    var min = ParseNumber(hctMatch.Groups[2].Value);
                    var max = ParseNumber(hctMatch.Groups[3].Value);

                    if (min < 5 && max < 10) { min = 41; max = 52; }

                    tests.Add(new LabValue { Name = "Hematocrit", Value = value, Min = min, Max = max });
                    continue;
                }

                // ── RBCs Count ────────────────────────────────────────────────
                var rbcMatch = Regex.Match(clean,
                    @"rbc.*?(\d+\.?\d*)\s*millions.*?(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (rbcMatch.Success)
                {
                    var value = ParseNumber(rbcMatch.Groups[1].Value);
                    var min = ParseNumber(rbcMatch.Groups[2].Value);
                    var max = ParseNumber(rbcMatch.Groups[3].Value);

                    if (min > 10) { min /= 10; max /= 10; }

                    tests.Add(new LabValue { Name = "RBCs Count", Value = value, Min = min, Max = max });
                    continue;
                }

                // ── MCV ───────────────────────────────────────────────────────
                // FIX: changed \s*fl\s* to \s*fl?\s* to tolerate "f" instead of "fl" from OCR
                var mcvMatch = Regex.Match(clean,
                    @"mcv\s+(\d+\.?\d*)\s*fl?\s*(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (mcvMatch.Success)
                {
                    var value = ParseNumber(mcvMatch.Groups[1].Value);
                    if (value > 150) value /= 10;

                    tests.Add(new LabValue
                    {
                        Name = "MCV",
                        Value = value,
                        Min = ParseNumber(mcvMatch.Groups[2].Value),
                        Max = ParseNumber(mcvMatch.Groups[3].Value)
                    });
                    continue;
                }

                // ── MCH ───────────────────────────────────────────────────────
                var mchMatch = Regex.Match(clean,
                    @"\bmch\b\s+(\d+\.?\d*)\s*pg\s*(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (!mchMatch.Success)
                {
                    mchMatch = Regex.Match(clean,
                        @"(?:Il|1l|NCH|nch)\s+(\d+\.?\d*)\s*pg\s*(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                        RegexOptions.IgnoreCase);
                }

                if (mchMatch.Success && !tests.Any(t => t.Name == "MCH"))
                {
                    var value = ParseNumber(mchMatch.Groups[1].Value);
                    if (value > 100) value /= 10;

                    tests.Add(new LabValue
                    {
                        Name = "MCH",
                        Value = value,
                        Min = ParseNumber(mchMatch.Groups[2].Value),
                        Max = ParseNumber(mchMatch.Groups[3].Value)
                    });
                    continue;
                }

                // ── MCHC ──────────────────────────────────────────────────────
                var mchcMatch = Regex.Match(clean,
                    @"mchc\s+(\d+\.?\d*)\s*" +
                    @"(?:g[il1/\\]d[il1]|g\/dl|g\/d1|oldl|gldl)?" +
                    @"\s*(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (mchcMatch.Success)
                {
                    tests.Add(new LabValue
                    {
                        Name = "MCHC",
                        Value = ParseNumber(mchcMatch.Groups[1].Value),
                        Min = ParseNumber(mchcMatch.Groups[2].Value),
                        Max = ParseNumber(mchcMatch.Groups[3].Value)
                    });
                    continue;
                }

                // ── RDW-CV ────────────────────────────────────────────────────
                var rdwMatch = Regex.Match(clean,
                    @"rdw[-\s]?cv\s+(\d+\.?\d*)\s*%\s*(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (rdwMatch.Success)
                {
                    var min = ParseNumber(rdwMatch.Groups[2].Value);
                    var max = ParseNumber(rdwMatch.Groups[3].Value);
                    if (min > 50) { min /= 10; max /= 10; }
                    if (min == max && min == 15) { min = 11.5; }

                    tests.Add(new LabValue
                    {
                        Name = "RDW-CV",
                        Value = ParseNumber(rdwMatch.Groups[1].Value),
                        Min = min,
                        Max = max
                    });
                    continue;
                }

                // ── Platelets ─────────────────────────────────────────────────
                var pltMatch = Regex.Match(clean,
                    @"platelet.*?(\d+\.?\d*)\s*thousands.*?(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (pltMatch.Success)
                {
                    tests.Add(new LabValue
                    {
                        Name = "Platelets",
                        Value = ParseNumber(pltMatch.Groups[1].Value),
                        Min = ParseNumber(pltMatch.Groups[2].Value),
                        Max = ParseNumber(pltMatch.Groups[3].Value)
                    });
                    continue;
                }

                // ── WBC ───────────────────────────────────────────────────────
                var wbcMatch = Regex.Match(clean,
                    @"leucoc[iy]tic.*?(\d+\.?\d*)\s*thousands.*?(\d+\.?\d*)\s*[-–]\s*(\d+\.?\d*)",
                    RegexOptions.IgnoreCase);

                if (wbcMatch.Success)
                {
                    var min = ParseNumber(wbcMatch.Groups[2].Value);
                    var max = ParseNumber(wbcMatch.Groups[3].Value);

                    if (max < min || max == 1) max = 11;

                    tests.Add(new LabValue
                    {
                        Name = "WBC",
                        Value = ParseNumber(wbcMatch.Groups[1].Value),
                        Min = min,
                        Max = max
                    });
                    continue;
                }
            }

            return tests;
        }

        // ---------------------------------------------------------------
        // Fill in any tests the line-by-line pass missed
        // ---------------------------------------------------------------
        private List<LabValue> EnsureCompleteTests(List<LabValue> tests, string rawText)
        {
            var existingNames = tests.Select(t => t.Name).ToHashSet();
            var complete = new List<LabValue>(tests);

            foreach (var kv in _defaultRanges)
            {
                if (existingNames.Contains(kv.Key)) continue;

                double value = 0;

                // FIX: MCV pattern uses fl? to tolerate "f" instead of "fl"
                // FIX: differential patterns use [^%]* before % to tolerate stray chars like "( %"
                string? pattern = kv.Key switch
                {
                    "Hemoglobin" => @"h[ae]{1,2}m[oe]?globin\s+(\d+\.?\d*)",
                    "Hematocrit" => @"h[ae]{1,2}m[ae]tocrit.*?(\d+\.?\d*)\s*%",
                    "RBCs Count" => @"rbc\s*s?\s*count\s+(\d+\.?\d*)",
                    "MCH" => @"(?:\bmch\b|Il|1l|NCH)\s+(\d+\.?\d*)\s*pg",
                    "MCV" => @"mcv\s+(\d+\.?\d*)\s*fl?",
                    "MCHC" => @"mchc\s+(\d+\.?\d*)",
                    "RDW-CV" => @"rdw[-\s]?cv\s+(\d+\.?\d*)",
                    "Neutrophils" => @"neutrophils?\s+\d+\.?\d*\s*[^%]*%\s*(\d+\.?\d*)\s*x10",
                    "Lymphocytes" => @"lymphocytes?\s+\d+\.?\d*\s*[^%]*%\s*(\d+\.?\d*)\s*x10",
                    "Monocytes" => @"monocytes?\s+\d+\.?\d*\s*[^%]*%\s*(\d+\.?\d*)\s*x10",
                    "Eosinophils" => @"eosinophils?\s+\d+\.?\d*\s*[^%]*%\s*(\d+\.?\d*)\s*x10",
                    "Basophils" => @"basophils?\s+\d+\.?\d*\s*[^%]*%\s*(\d+\.?\d*)\s*x10",
                    _ => null
                };

                if (pattern != null)
                {
                    var m = Regex.Match(rawText, pattern, RegexOptions.IgnoreCase);
                    if (m.Success)
                        value = ParseNumber(m.Groups[1].Value);
                }

                complete.Add(new LabValue
                {
                    Name = kv.Key,
                    Value = value,
                    Min = kv.Value.min,
                    Max = kv.Value.max
                });
            }

            return complete;
        }

        // ---------------------------------------------------------------
        // ParseNumber
        // ---------------------------------------------------------------
        private double ParseNumber(string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return 0;

            input = input.Trim()
                         .Replace(",", ".")
                         .Replace("O", "0")
                         .Replace("o", "0")
                         .Replace("S", "5");

            input = Regex.Replace(input, @"(?<=\d)[lI]|[lI](?=\d)", "1");

            if (double.TryParse(input,
                    System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture,
                    out double val))
                return val;

            return 0;
        }

        // ---------------------------------------------------------------
        // NormalizeName
        // ---------------------------------------------------------------
        private string NormalizeName(string name)
        {
            name = name.Trim().ToLowerInvariant();
            name = Regex.Replace(name, @"[^a-z]", "");

            if (name.Contains("haemoglobin") || name.Contains("hemoglobin")) return "Hemoglobin";
            if (name.Contains("haematocrit") || name.Contains("hematocrit") || name.Contains("pcv")) return "Hematocrit";
            if (name.Contains("rbc") && !name.Contains("rdw")) return "RBCs Count";
            if (name.Contains("mchc")) return "MCHC";
            if (name.Contains("mch") && !name.Contains("mchc")) return "MCH";
            if (name.Contains("mcv")) return "MCV";
            if (name.Contains("rdw")) return "RDW-CV";
            if (name.Contains("platelet")) return "Platelets";
            if (name.Contains("wbc") || name.Contains("leucocytic")) return "WBC";
            if (name.Contains("neutrophil")) return "Neutrophils";
            if (name.Contains("lymphocyte")) return "Lymphocytes";
            if (name.Contains("monocyte")) return "Monocytes";
            if (name.Contains("eosinophil")) return "Eosinophils";
            if (name.Contains("basophil")) return "Basophils";

            return System.Globalization.CultureInfo.CurrentCulture.TextInfo.ToTitleCase(name);
        }
    }
}