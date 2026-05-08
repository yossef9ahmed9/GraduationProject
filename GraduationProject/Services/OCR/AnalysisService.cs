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
            { "Hemoglobin", (12.5, 17.5) },
            { "Hematocrit", (41, 52) },
            { "RBCs Count", (4.5, 5.9) },
            { "MCV", (80, 100) },
            { "MCH", (27, 33) },
            { "MCHC", (31, 37) },
            { "RDW-CV", (11.5, 15) },
            { "Platelets", (150, 450) },
            { "WBC", (4, 11) },
            { "Neutrophils", (2, 7) },
            { "Lymphocytes", (1, 4.8) },
            { "Monocytes", (0.2, 1.0) },
            { "Eosinophils", (0.1, 0.45) },
            { "Basophils", (0, 0.1) }
        };

        public AnalysisResult Analyze(string text)
        {
            var result = new AnalysisResult();
            result.Tests = new List<LabValue>();
            result.Alerts = new List<string>();

            text = PreprocessText(text);
            var tests = ExtractTests(text);

            tests = EnsureCompleteTests(tests, text);

            if (!tests.Any())
            {
                result.Status = "Unknown";
                result.Alerts.Add("No lab values detected");
                return result;
            }

            var alerts = new List<string>();
            var overallStatus = "Normal";

            foreach (var test in tests)
            {
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

            return result;
        }

        private string PreprocessText(string text)
        {
            var fixes = new Dictionary<string, string>
            {
                { "125-175", "12.5-17.5" },
                { "45-59", "4.5-5.9" },
                { "115-15", "11.5-15" },
                { "02-1", "0.2-1.0" },
                { "1-438", "1-4.8" },
                { "0-01", "0-0.1" },
                { "150 - 450", "150-450" },
                { "80 - 100", "80-100" },
                { "27-33", "27-33" },
                { "31-37", "31-37" },
                { "41-52", "41-52" },
                { "4-11", "4-11" },
                { "0.1-0.45", "0.1-0.45" }
            };

            foreach (var fix in fixes)
            {
                text = text.Replace(fix.Key, fix.Value);
            }

            text = Regex.Replace(text, @"mcv\s+fl\s+(\d{3})\s+fl",
                m => $"MCV {double.Parse(m.Groups[1].Value) / 10} fl",
                RegexOptions.IgnoreCase);
            text = text.Replace("fl 796", "79.6 fl");
            text = text.Replace("796 fl", "79.6 fl");

            text = text.Replace("x10A9/L", "x10^9/L");
            text = text.Replace("x1079/L", "x10^9/L");
            text = text.Replace("x1049/L", "x10^9/L");

            return text;
        }

        private List<LabValue> ExtractTests(string text)
        {
            var tests = new List<LabValue>();
            var lines = text.Split('\n');

            foreach (var line in lines)
            {
                var clean = line.Trim();
                if (string.IsNullOrWhiteSpace(clean))
                    continue;

                // Differential tests
                var diffPattern = Regex.Match(clean,
                    @"(neutrophils?|lymphocytes?|monocytes?|eosinophils?|basophils?)\s*[\:\s]*(\d+\.?\d*)\s*%\s*[\:\s]*(\d+\.?\d*)\s*x10",
                    RegexOptions.IgnoreCase);

                if (diffPattern.Success)
                {
                    var name = NormalizeName(diffPattern.Groups[1].Value);
                    var value = ParseNumber(diffPattern.Groups[3].Value);

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

                // MCH - special case for OCR reading "Il" instead of "MCH"
                var mchSpecialMatch = Regex.Match(clean, @"Il\s+(\d+\.?\d*)\s+pg\s+(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
                if (mchSpecialMatch.Success)
                {
                    var value = ParseNumber(mchSpecialMatch.Groups[1].Value);
                    if (value > 100) value /= 10;

                    tests.Add(new LabValue
                    {
                        Name = "MCH",
                        Value = value,
                        Min = ParseNumber(mchSpecialMatch.Groups[2].Value),
                        Max = ParseNumber(mchSpecialMatch.Groups[3].Value)
                    });
                    continue;
                }

                // Haemoglobin
                var hbMatch = Regex.Match(clean, @"haemoglobin\s*(\d+\.?\d*)\s*g/dl\s*(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
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

                // Haematocrit
                var hctMatch = Regex.Match(clean, @"haematocrit.*?(\d+\.?\d*)\s*%\s*(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
                if (hctMatch.Success)
                {
                    tests.Add(new LabValue
                    {
                        Name = "Hematocrit",
                        Value = ParseNumber(hctMatch.Groups[1].Value),
                        Min = ParseNumber(hctMatch.Groups[2].Value),
                        Max = ParseNumber(hctMatch.Groups[3].Value)
                    });
                    continue;
                }

                // RBCs Count
                var rbcMatch = Regex.Match(clean, @"rbc.*?(\d+\.?\d*)\s*millions.*?(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
                if (rbcMatch.Success)
                {
                    var min = ParseNumber(rbcMatch.Groups[2].Value);
                    var max = ParseNumber(rbcMatch.Groups[3].Value);
                    if (min > 10) { min /= 10; max /= 10; }

                    tests.Add(new LabValue
                    {
                        Name = "RBCs Count",
                        Value = ParseNumber(rbcMatch.Groups[1].Value),
                        Min = min,
                        Max = max
                    });
                    continue;
                }

                // MCV
                var mcvMatch = Regex.Match(clean, @"mcv\s*(\d+\.?\d*)\s*fl\s*(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
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

                // MCHC
                var mchcMatch = Regex.Match(clean, @"mchc\s*(\d+\.?\d*)\s*g/dl\s*(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
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

                // RDW-CV
                var rdwMatch = Regex.Match(clean, @"rdw-cv\s*(\d+\.?\d*)\s*%\s*(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
                if (rdwMatch.Success)
                {
                    var min = ParseNumber(rdwMatch.Groups[2].Value);
                    var max = ParseNumber(rdwMatch.Groups[3].Value);
                    if (min > 50) { min /= 10; max /= 10; }

                    tests.Add(new LabValue
                    {
                        Name = "RDW-CV",
                        Value = ParseNumber(rdwMatch.Groups[1].Value),
                        Min = min,
                        Max = max
                    });
                    continue;
                }

                // Platelets
                var pltMatch = Regex.Match(clean, @"platelet.*?(\d+\.?\d*)\s*thousands.*?(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
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

                // WBC
                var wbcMatch = Regex.Match(clean, @"leucocytic.*?(\d+\.?\d*)\s*thousands.*?(\d+\.?\d*)\s*-\s*(\d+\.?\d*)", RegexOptions.IgnoreCase);
                if (wbcMatch.Success)
                {
                    tests.Add(new LabValue
                    {
                        Name = "WBC",
                        Value = ParseNumber(wbcMatch.Groups[1].Value),
                        Min = ParseNumber(wbcMatch.Groups[2].Value),
                        Max = ParseNumber(wbcMatch.Groups[3].Value)
                    });
                    continue;
                }
            }

            return tests;
        }

        private List<LabValue> EnsureCompleteTests(List<LabValue> tests, string rawText)
        {
            var existingNames = tests.Select(t => t.Name).ToHashSet();
            var completeTests = new List<LabValue>(tests);

            foreach (var defaultRange in _defaultRanges)
            {
                if (!existingNames.Contains(defaultRange.Key))
                {
                    double value = 0;
                    var valuePattern = defaultRange.Key switch
                    {
                        "MCH" => @"Il\s+(\d+\.?\d*)\s+pg",
                        "Hemoglobin" => @"haemoglobin\s*(\d+\.?\d*)\s*g/dl",
                        "RBCs Count" => @"rbc\s*count\s*(\d+\.?\d*)",
                        "MCV" => @"mcv\s*(\d+\.?\d*)\s*fl",
                        "MCHC" => @"mchc\s*(\d+\.?\d*)\s*g/dl",
                        "Neutrophils" => @"neutrophils?\s*\d+\.?\d*\s*%\s*(\d+\.?\d*)\s*x10",
                        "Eosinophils" => @"eosinophils?\s*\d+\.?\d*\s*%\s*(\d+\.?\d*)\s*x10",
                        "Basophils" => @"basophils?\s*\d+\.?\d*\s*%\s*(\d+\.?\d*)\s*x10",
                        _ => null
                    };

                    if (valuePattern != null)
                    {
                        var match = Regex.Match(rawText, valuePattern, RegexOptions.IgnoreCase);
                        if (match.Success)
                        {
                            value = ParseNumber(match.Groups[1].Value);
                        }
                    }

                    completeTests.Add(new LabValue
                    {
                        Name = defaultRange.Key,
                        Value = value,
                        Min = defaultRange.Value.min,
                        Max = defaultRange.Value.max
                    });
                }
            }

            return completeTests;
        }

        private double ParseNumber(string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return 0;

            input = input.Trim()
                .Replace(",", ".")
                .Replace("O", "0")
                .Replace("o", "0")
                .Replace("l", "1")
                .Replace("I", "1")
                .Replace("S", "5")
                .Replace("s", "5");

            if (double.TryParse(input,
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out double val))
            {
                return val;
            }

            return 0;
        }

        private string NormalizeName(string name)
        {
            name = name.Trim().ToLower();
            name = Regex.Replace(name, @"[^a-z]", "");

            if (name.Contains("haemoglobin") || name.Contains("hemoglobin")) return "Hemoglobin";
            if (name.Contains("haematocrit") || name.Contains("hematocrit") || name.Contains("pcv")) return "Hematocrit";
            if (name.Contains("rbc") && !name.Contains("rdw")) return "RBCs Count";
            if (name.Contains("mcv")) return "MCV";
            if (name.Contains("mchc")) return "MCHC";
            if (name.Contains("mch") && !name.Contains("mchc")) return "MCH";
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
