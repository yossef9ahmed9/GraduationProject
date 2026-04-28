using GraduationProject.Contracts.OCR;
using System.Text.RegularExpressions;

namespace GraduationProject.Services.OCR
{
    public class AnalysisService : IAnalysisService
    {
        public AnalysisResult Analyze(string text)
        {
            var result = new AnalysisResult();

            text = Normalize(text);

            var tests = ExtractTests(text);

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
                    alerts.Add($"{test.Name} is Low");
                    overallStatus = "Warning";
                }
                else if (test.Max.HasValue && test.Value > test.Max)
                {
                    test.Status = "High";
                    alerts.Add($"{test.Name} is High");
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

        // =====================

        private List<LabValue> ExtractTests(string text)
        {
            var list = new List<LabValue>();

            var lines = text.Split('\n');

            foreach (var line in lines)
            {
                var clean = line.Trim();

                if (string.IsNullOrWhiteSpace(clean))
                    continue;

                // 🔥 strict pattern (يمنع الهيدر)
                var match = Regex.Match(
                    clean,
                    @"^([a-z][a-z\s\(\)\-]+)\s+(\d+\.?\d*)\s+[a-z/%\.\s]*\s+(\d+\.?\d*)\s*-\s*(\d+\.?\d*)$",
                    RegexOptions.IgnoreCase
                );

                if (!match.Success)
                    continue;

                var name = NormalizeName(match.Groups[1].Value);

                var value = FixNumber(match.Groups[2].Value);
                var min = FixNumber(match.Groups[3].Value);
                var max = FixNumber(match.Groups[4].Value);

                list.Add(new LabValue
                {
                    Name = name,
                    Value = value,
                    Min = min,
                    Max = max
                });
            }

            return list;
        }

        // =====================

        private double FixNumber(string input)
        {
            input = input.Replace(",", ".");

            double.TryParse(input, out double val);

            // 🔥 تصحيح OCR error (4.6 → 46)
            if (val > 0 && val < 10)
                val *= 10;

            return val;
        }

        // =====================

        private string Normalize(string text)
        {
            text = text.ToLower();

            text = text.Replace("↓", "")
                       .Replace("↑", "")
                       .Replace("|", " ")
                       .Replace("—", "-");

            var lines = text.Split('\n');

            var cleaned = new List<string>();

            foreach (var l in lines)
            {
                var line = l.Trim();

                if (string.IsNullOrWhiteSpace(line))
                    continue;

                // ❌ remove headers
                var nums = Regex.Matches(line, @"\d+");

                if (nums.Count < 2)
                    continue;

                // ❌ remove metadata
                if (line.Contains("patient") ||
                    line.Contains("visit") ||
                    line.Contains("printed"))
                    continue;

                // ❌ remove dates
                if (Regex.IsMatch(line, @"\d{2}-\d{2}-\d{4}"))
                    continue;

                cleaned.Add(line);
            }

            return string.Join("\n", cleaned);
        }

        private string NormalizeName(string name)
        {
            name = name.Trim().ToLower();

            if (name.Contains("hgb")) return "hemoglobin";
            if (name.Contains("rbc")) return "rbcs count";
            if (name.Contains("mcv")) return "mcv";
            if (name.Contains("mchc")) return "mchc";
            if (name.Contains("mch")) return "mch";
            if (name.Contains("rdw")) return "rdw";
            if (name.Contains("platelet")) return "platelet";
            if (name.Contains("wbc") || name.Contains("leuco")) return "wbc";

            return name;
        }
    }
}