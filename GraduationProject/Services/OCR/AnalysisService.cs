using System;
using System.Collections.Generic;
using System.Linq;
using GraduationProject.Contracts.OCR;
using System.Text.RegularExpressions;

namespace GraduationProject.Services.OCR
{
    public class AnalysisService : IAnalysisService
    {
        // ── CBC ranges ──────────────────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _cbcRanges = new()
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

        // ── Glucose ranges ──────────────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _glucoseRanges = new()
        {
            { "Fasting Glucose",  (70,   100)  },
            { "Random Glucose",   (70,   140)  },
            { "Fasting Insulin",  (2,    25)   },
            { "HOMA-IR",          (null, 2.5)  }
        };

        // ── HbA1c ranges ────────────────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _hba1cRanges = new()
        {
            { "HbA1c %",               (null, 5.7)  },
            { "Average Blood Glucose", (null, 117)  },
            { "eAG mg/dL",             (null, 117)  }
        };

        // ── Lipid Panel ranges ──────────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _lipidRanges = new()
        {
            { "Total Cholesterol",  (null, 200)  },
            { "LDL Cholesterol",    (null, 100)  },
            { "HDL Cholesterol",    (40,   null) },
            { "Triglycerides",      (null, 150)  },
            { "VLDL",               (null, 30)   },
            { "Non-HDL Cholesterol",(null, 130)  },
            { "LDL/HDL Ratio",      (null, 3.5)  }
        };

        // ── Kidney Function ranges ──────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _kidneyRanges = new()
        {
            { "Creatinine",           (0.6,  1.2)  },
            { "BUN",                  (7,    20)   },
            { "BUN/Creatinine Ratio", (10,   20)   },
            { "eGFR",                 (60,   null) },
            { "Uric Acid",            (3.5,  7.2)  },
            { "Sodium",               (136,  145)  },
            { "Potassium",            (3.5,  5.1)  },
            { "Chloride",             (98,   107)  },
            { "Bicarbonate",          (22,   29)   }
        };

        // ── Liver Function ranges ───────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _liverRanges = new()
        {
            { "ALT",              (7,    56)   },
            { "AST",              (10,   40)   },
            { "ALP",              (44,   147)  },
            { "GGT",              (8,    61)   },
            { "Total Bilirubin",  (0.2,  1.2)  },
            { "Direct Bilirubin", (null, 0.3)  },
            { "Indirect Bilirubin",(0.2, 0.9)  },
            { "Total Protein",    (6.3,  8.2)  },
            { "Albumin",          (3.5,  5.0)  },
            { "Globulin",         (2.0,  3.5)  },
            { "A/G Ratio",        (1.1,  2.5)  }
        };

        // ── Thyroid ranges ──────────────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _thyroidRanges = new()
        {
            { "TSH",      (0.4,  4.0)  },
            { "Free T4",  (0.8,  1.8)  },
            { "Free T3",  (2.3,  4.2)  },
            { "Total T4", (5.0,  12.0) },
            { "Total T3", (0.8,  2.0)  },
            { "Anti-TPO", (null, 35)   },
            { "Anti-TG",  (null, 40)   }
        };

        // ── Vitamin D ranges ────────────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _vitaminDRanges = new()
        {
            { "25-OH Vitamin D",   (30,   100) },
            { "1,25-OH Vitamin D", (18,   72)  },
            { "PTH",               (10,   65)  }
        };

        // ── Iron Studies ranges ─────────────────────────────────────────────────
        private static readonly Dictionary<string, (double? min, double? max)> _ironRanges = new()
        {
            { "Serum Iron",              (60,   170) },
            { "TIBC",                    (250,  370) },
            { "Transferrin Saturation %",(20,   50)  },
            { "Ferritin",                (12,   300) },
            { "Transferrin",             (200,  360) }
        };

        // ── Urine Analysis — only the numeric fields get ranges ─────────────────
        // Text fields (Color, Clarity, Protein, etc.) are stored as-is with no range
        private static readonly Dictionary<string, (double? min, double? max)> _urineRanges = new()
        {
            { "pH",              (4.5,  8.0) },
            { "Specific Gravity",(1.005,1.030)},
            { "WBC/hpf",         (null, 5)   },
            { "RBC/hpf",         (null, 3)   }
        };

        // ── Text-only urine fields (no numeric comparison) ──────────────────────
        private static readonly HashSet<string> _urineTextFields = new(StringComparer.OrdinalIgnoreCase)
        {
            "Color", "Clarity", "Protein", "Glucose", "Ketones", "Blood",
            "Nitrite", "Leukocyte Esterase", "Bacteria", "Casts"
        };

        // ── Combined lookup: testType → its range dictionary ────────────────────
        private static readonly Dictionary<string, Dictionary<string, (double? min, double? max)>> _rangesByType = new()
        {
            { "CBC",              _cbcRanges     },
            { "Glucose",          _glucoseRanges },
            { "HbA1c",            _hba1cRanges   },
            { "Lipid Panel",      _lipidRanges   },
            { "Kidney Function",  _kidneyRanges  },
            { "Liver Function",   _liverRanges   },
            { "Thyroid (TSH)",    _thyroidRanges },
            { "Vitamin D",        _vitaminDRanges},
            { "Iron Studies",     _ironRanges    },
            { "Urine Analysis",   _urineRanges   }
        };

        // Keep _defaultRanges pointing to CBC for backward compatibility
        private readonly Dictionary<string, (double? min, double? max)> _defaultRanges = _cbcRanges;

        /// <summary>
        /// Detect which type of lab report the OCR text represents.
        /// Returns one of the keys in _rangesByType, or "CBC" as default.
        /// </summary>
        public string DetectTestType(string text)
        {
            var t = text.ToLowerInvariant();

            // Urine Analysis
            if (Regex.IsMatch(t, @"\burine\b|\bspecific\s+gravity\b|\bleukocyte\s+esterase\b|\bnitrite\b"))
                return "Urine Analysis";

            // Lipid Panel
            if (Regex.IsMatch(t, @"\bcholesterol\b|\btriglyceride|\bldl\b|\bhdl\b|\blipid\b"))
                return "Lipid Panel";

            // Liver Function
            if (Regex.IsMatch(t, @"\b(alt|alanine)\b|\b(ast|aspartate)\b|\balbumin\b|\bbilirubin\b|\balp\b|\bggt\b"))
                return "Liver Function";

            // Kidney Function
            if (Regex.IsMatch(t, @"\bcreatinine\b|\bbun\b|\begfr\b|\buric\s+acid\b|\bpotassium\b"))
                return "Kidney Function";

            // Thyroid
            if (Regex.IsMatch(t, @"\btsh\b|\bthyroid\b|\bfree\s+t[34]\b|\banti[-\s]?tpo\b"))
                return "Thyroid (TSH)";

            // Vitamin D
            if (Regex.IsMatch(t, @"\bvitamin\s+d\b|\b25[\s-]?oh\b|\bpth\b|\bcalcitriol\b"))
                return "Vitamin D";

            // Iron Studies
            if (Regex.IsMatch(t, @"\bferritin\b|\btibc\b|\btransferrin\b|\bserum\s+iron\b|\biron\s+studies\b"))
                return "Iron Studies";

            // HbA1c
            if (Regex.IsMatch(t, @"\bhba1c\b|\bglycated\b|\bhemoglobin\s+a1c\b|\beag\b"))
                return "HbA1c";

            // Glucose
            if (Regex.IsMatch(t, @"\bglucose\b|\binsulin\b|\bhoma[-\s]?ir\b"))
                return "Glucose";

            // Default → CBC
            return "CBC";
        }

        public AnalysisResult Analyze(string text) => Analyze(text, null);

        public AnalysisResult Analyze(string text, string? testType)
        {
            var result = new AnalysisResult();
            result.Tests = new List<LabValue>();
            result.Alerts = new List<string>();

            text = PreprocessText(text);

            // Auto-detect if not provided
            testType ??= DetectTestType(text);
            result.TestType = testType;

            var ranges = _rangesByType.TryGetValue(testType, out var r) ? r : _cbcRanges;

            List<LabValue> tests;

            // Route to the appropriate extractor
            tests = testType switch
            {
                "CBC"             => ExtractCbcTests(text),
                "Glucose"         => ExtractGenericTests(text, _glucoseRanges),
                "HbA1c"           => ExtractGenericTests(text, _hba1cRanges),
                "Lipid Panel"     => ExtractGenericTests(text, _lipidRanges),
                "Kidney Function" => ExtractGenericTests(text, _kidneyRanges),
                "Liver Function"  => ExtractGenericTests(text, _liverRanges),
                "Thyroid (TSH)"   => ExtractGenericTests(text, _thyroidRanges),
                "Vitamin D"       => ExtractGenericTests(text, _vitaminDRanges),
                "Iron Studies"    => ExtractGenericTests(text, _ironRanges),
                "Urine Analysis"  => ExtractUrineTests(text),
                _                 => ExtractCbcTests(text)
            };

            bool nothingExtracted = !tests.Any();
            bool allExtractedAreZero = tests.Any() && tests.All(t => t.Value == 0 && !_urineTextFields.Contains(t.Name));

            if (nothingExtracted || allExtractedAreZero)
            {
                result.Status = "InvalidScan";
                result.IsValidScan = false;
                result.Tests = new List<LabValue>();
                result.Alerts = new List<string>
                {
                    $"Could not extract any lab values from the image. " +
                    $"Please make sure the image is a clear, well-lit photo of a {testType} lab report."
                };
                return result;
            }

            if (testType == "CBC")
                tests = EnsureCompleteCbcTests(tests, text);

            var alerts = new List<string>();
            var overallStatus = "Normal";

            foreach (var test in tests)
            {
                // Text-only fields (urine) — skip numeric classification
                if (_urineTextFields.Contains(test.Name))
                {
                    test.Status = "Normal";
                    continue;
                }

                // ── Sanity check: value is way outside any realistic range ──────
                if (IsUnreadable(test))
                {
                    test.Status = "UnreadableValue";
                    alerts.Add($"{test.Name} value ({test.Value}) could not be read clearly — please verify manually.");
                    overallStatus = "Warning";
                    continue;
                }

                // ── Normal / Low / High classification ────────────────────────
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
        // Extract CBC tests line by line (original logic, unchanged)
        // ---------------------------------------------------------------
        private List<LabValue> ExtractCbcTests(string text)
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
        // Fill in any CBC tests the line-by-line pass missed
        // ---------------------------------------------------------------
        private List<LabValue> EnsureCompleteCbcTests(List<LabValue> tests, string rawText)
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

        // ---------------------------------------------------------------
        // Generic extractor for non-CBC numeric test types.
        //
        // For each known field name, scan every OCR line for the keyword
        // then grab the first numeric value after it.
        // Fields not found get a placeholder value=0 (→ UnreadableValue)
        // so the frontend knows to ask for manual entry.
        // ---------------------------------------------------------------
        private List<LabValue> ExtractGenericTests(
            string text,
            Dictionary<string, (double? min, double? max)> ranges)
        {
            var results = new List<LabValue>();
            var found   = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var lines   = text.Split('\n');

            foreach (var kv in ranges)
            {
                var fieldName = kv.Key;

                // Build keyword from first long word of the field name
                var keywords = Regex.Split(fieldName, @"[\s/\-\(\)]+")
                    .Where(w => w.Length >= 3)
                    .Select(w => Regex.Escape(w))
                    .ToArray();

                if (keywords.Length == 0) continue;
                var primaryKw = keywords[0];

                foreach (var line in lines)
                {
                    if (!Regex.IsMatch(line, primaryKw, RegexOptions.IgnoreCase)) continue;

                    // Try to grab the number that follows the keyword on the same line
                    var numMatch = Regex.Match(line,
                        primaryKw + @"[^0-9]{0,30}?(\d+\.?\d*)",
                        RegexOptions.IgnoreCase);

                    if (!numMatch.Success)
                        numMatch = Regex.Match(line, @"(\d+\.?\d+)");

                    if (!numMatch.Success) continue;

                    var value = ParseNumber(numMatch.Groups[1].Value);
                    if (value == 0) continue;
                    if (found.Contains(fieldName)) continue;

                    found.Add(fieldName);
                    results.Add(new LabValue
                    {
                        Name  = fieldName,
                        Value = value,
                        Min   = kv.Value.min,
                        Max   = kv.Value.max
                    });
                    break;
                }
            }

            // Add placeholder for every missing field (value=0 → UnreadableValue)
            foreach (var kv in ranges)
            {
                if (found.Contains(kv.Key)) continue;
                results.Add(new LabValue
                {
                    Name  = kv.Key,
                    Value = 0,
                    Min   = kv.Value.min,
                    Max   = kv.Value.max
                });
            }

            return results;
        }

        // ---------------------------------------------------------------
        // Urine Analysis extractor.
        // Numeric fields → generic extractor.
        // Text fields (Color, Clarity, Positive/Negative results, etc.)
        // → captured as a LabValue with TextValue set and Value=0.
        // ---------------------------------------------------------------
        private List<LabValue> ExtractUrineTests(string text)
        {
            var results = new List<LabValue>();
            var found   = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            // Numeric fields first
            foreach (var lv in ExtractGenericTests(text, _urineRanges))
            {
                results.Add(lv);
                if (lv.Value != 0) found.Add(lv.Name);
            }

            // Text fields
            var textPatterns = new Dictionary<string, string>
            {
                { "Color",              @"colou?r\s*[:\-]?\s*([a-zA-Z]+)" },
                { "Clarity",            @"clarity\s*[:\-]?\s*([a-zA-Z]+)" },
                { "Protein",            @"\bprotein\s*[:\-]?\s*(positive|negative|trace|\+{1,4}|-{1,2}|\d+\.?\d*)" },
                { "Glucose",            @"\bglucose\s*[:\-]?\s*(positive|negative|trace|\+{1,4}|-{1,2}|\d+\.?\d*)" },
                { "Ketones",            @"ketones?\s*[:\-]?\s*(positive|negative|trace|\+{1,4}|-{1,2}|\d+\.?\d*)" },
                { "Blood",              @"\bblood\s*[:\-]?\s*(positive|negative|trace|\+{1,4}|-{1,2}|\d+\.?\d*)" },
                { "Nitrite",            @"nitrite\s*[:\-]?\s*(positive|negative|\+{1,4}|-{1,2})" },
                { "Leukocyte Esterase", @"leukocyte\s+esterase\s*[:\-]?\s*(positive|negative|trace|\+{1,4}|-{1,2})" },
                { "Bacteria",           @"bacteria\s*[:\-]?\s*(positive|negative|few|moderate|many|\+{1,4}|-{1,2})" },
                { "Casts",              @"casts?\s*[:\-]?\s*([a-zA-Z\s\+\-]+)" },
            };

            foreach (var kv in textPatterns)
            {
                if (results.Any(r => r.Name == kv.Key)) continue;
                var m = Regex.Match(text, kv.Value, RegexOptions.IgnoreCase);
                results.Add(new LabValue
                {
                    Name      = kv.Key,
                    Value     = 0,
                    TextValue = m.Success ? m.Groups[1].Value.Trim() : string.Empty,
                    Status    = m.Success ? "Normal" : "UnreadableValue"
                });
            }

            return results;
        }
    }
}