using GraduationProject.Contracts.OCR;
using System.Text.RegularExpressions;

namespace GraduationProject.Services.OCR
{
    public class AnalysisService : IAnalysisService
    {
        private static readonly Dictionary<string, (double Min, double Max)> ReferenceRanges = new()
        {
            { "hemoglobin",          (12.0, 17.5) },
            { "hgb",                 (12.0, 17.5) },
            { "wbc",                 (4.0, 11.0) },
            { "rbc",                 (3.8, 5.8) },
            { "platelets",           (150.0, 400.0) },
            { "platelet",            (150.0, 400.0) },
            { "hematocrit",          (36.0, 52.0) },
            { "mcv",                 (80.0, 100.0) },
            { "mch",                 (27.0, 33.0) },
            { "mchc",                (32.0, 36.0) },
            { "rdw",                 (11.5, 14.5) },
            { "neutrophils",         (40.0, 75.0) },
            { "lymphocytes",         (20.0, 45.0) },
            { "monocytes",           (2.0, 10.0) },
            { "eosinophils",         (1.0, 6.0) },
            { "basophils",           (0.0, 1.0) },
            { "glucose",             (70.0, 100.0) },
            { "blood glucose",       (70.0, 100.0) },
            { "creatinine",          (0.6, 1.2) },
            { "urea",                (7.0, 20.0) },
            { "sodium",              (136.0, 145.0) },
            { "potassium",           (3.5, 5.0) },
            { "chloride",            (98.0, 107.0) },
            { "calcium",             (8.5, 10.5) },
            { "albumin",             (3.5, 5.0) },
            { "total protein",       (6.0, 8.3) },
            { "bilirubin",           (0.2, 1.2) },
            { "alt",                 (7.0, 56.0) },
            { "ast",                 (10.0, 40.0) },
            { "alkaline phosphatase",(44.0, 147.0) },
            { "tsh",                 (0.4, 4.0) },
            { "cholesterol",         (0.0, 200.0) },
            { "triglycerides",       (0.0, 150.0) },
            { "hdl",                 (40.0, 60.0) },
            { "ldl",                 (0.0, 100.0) },
        };

        public AnalysisResult Analyze(string text)
        {
            var result = new AnalysisResult();

            var cleanedText = Normalize(text);

            var tests = ExtractTests(cleanedText);

            if (!tests.Any())
            {
                result.Status = "Unknown";

                result.Alerts.Add(
                    "No lab values could be detected in this report.");

                result.Alerts.Add(
                    "Please make sure the image is clear and contains a standard lab report format.");

                return result;
            }

            var alerts = new List<string>();

            var overallStatus = "Normal";

            foreach (var test in tests)
            {
                double? min = test.Min;
                double? max = test.Max;

                if (!min.HasValue || !max.HasValue)
                {
                    var key = ReferenceRanges.Keys
                        .FirstOrDefault(k =>
                            test.Name.Contains(
                                k,
                                StringComparison.OrdinalIgnoreCase));

                    if (key != null)
                    {
                        min = ReferenceRanges[key].Min;
                        max = ReferenceRanges[key].Max;

                        test.Min = min;
                        test.Max = max;
                    }
                }

                if (min.HasValue && test.Value < min.Value)
                {
                    test.Status = "Low";

                    alerts.Add(
                        $"{test.Name} is Low ({test.Value} — normal: {min}-{max})");

                    overallStatus = "Warning";
                }
                else if (max.HasValue && test.Value > max.Value)
                {
                    test.Status = "High";

                    alerts.Add(
                        $"{test.Name} is High ({test.Value} — normal: {min}-{max})");

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

        private List<LabValue> ExtractTests(string text)
        {
            var list = new List<LabValue>();

            var lines = text.Split('\n');

            foreach (var line in lines)
            {
                var clean = line.Trim();

                if (string.IsNullOrWhiteSpace(clean))
                    continue;

                var result = TryPatternWithRange(clean);

                if (result != null)
                {
                    list.Add(result);
                    continue;
                }

                result = TryPatternValueOnly(clean);

                if (result != null)
                {
                    list.Add(result);
                }
            }

            return list;
        }

        private double? SafeParseNumber(string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return null;

            input = input.Trim().Replace(",", ".");

            if (double.TryParse(
                input,
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out double val))
            {
                return val;
            }

            return null;
        }

        private LabValue? TryPatternWithRange(string line)
        {
            var match = Regex.Match(
                line,
                @"^([a-z][a-z0-9\s\(\)\-\.]+?)\s+" +
                @"(\d+[\.,]?\d*)\s+" +
                @"[a-z/%\.\s]*\s*" +
                @"(\d+[\.,]?\d*)\s*[-–]\s*(\d+[\.,]?\d*)$",
                RegexOptions.IgnoreCase
            );

            if (!match.Success)
                return null;

            var name = NormalizeName(match.Groups[1].Value);

            var value = SafeParseNumber(match.Groups[2].Value);

            var min = SafeParseNumber(match.Groups[3].Value);

            var max = SafeParseNumber(match.Groups[4].Value);

            if (!value.HasValue)
                return null;

            if (value.Value <= 0 || value.Value > 100000)
                return null;

            return new LabValue
            {
                Name = name,
                Value = value.Value,
                Min = min,
                Max = max
            };
        }

        private LabValue? TryPatternValueOnly(string line)
        {
            var match = Regex.Match(
                line,
                @"^([a-z][a-z0-9\s\(\)\-\.]+?)\s+" +
                @"(\d+[\.,]?\d*)\s*" +
                @"[a-z/%\.\s]*$",
                RegexOptions.IgnoreCase
            );

            if (!match.Success)
                return null;

            var name = NormalizeName(match.Groups[1].Value);

            var knownTest = ReferenceRanges.Keys
                .Any(k =>
                    name.Contains(
                        k,
                        StringComparison.OrdinalIgnoreCase));

            if (!knownTest)
                return null;

            var value = SafeParseNumber(match.Groups[2].Value);

            if (!value.HasValue ||
                value.Value <= 0 ||
                value.Value > 100000)
                return null;

            return new LabValue
            {
                Name = name,
                Value = value.Value,
                Min = null,
                Max = null
            };
        }

        private string Normalize(string text)
        {
            text = text.ToLower();

            text = text
                .Replace("↓", " low ")
                .Replace("↑", " high ")
                .Replace("|", " ")
                .Replace("—", "-")
                .Replace("–", "-")
                .Replace("\r\n", "\n")
                .Replace("\r", "\n");

            var lines = text.Split('\n');

            var cleaned = new List<string>();

            foreach (var l in lines)
            {
                var line = l.Trim();

                if (string.IsNullOrWhiteSpace(line))
                    continue;

                if (!Regex.IsMatch(line, @"\d"))
                    continue;

                if (line.Contains("patient") ||
                    line.Contains("date of birth") ||
                    line.Contains("visit") ||
                    line.Contains("printed") ||
                    line.Contains("report") ||
                    line.Contains("laboratory") ||
                    line.Contains("doctor") ||
                    line.Contains("physician") ||
                    line.Contains("name") ||
                    line.Contains("age") ||
                    line.Contains("gender") ||
                    line.Contains("ref") && line.Contains("range") ||
                    line.Contains("test") && line.Contains("result") && line.Contains("unit"))
                    continue;

                if (Regex.IsMatch(
                    line,
                    @"\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}"))
                    continue;

                if (Regex.IsMatch(line, @"^\d+$"))
                    continue;

                cleaned.Add(line);
            }

            return string.Join("\n", cleaned);
        }

        private string NormalizeName(string name)
        {
            name = name.Trim().ToLower();

            name = name.TrimEnd('.', '-', ' ');

            if (name.Contains("hgb") ||
                name.Contains("haemoglobin"))
                return "hemoglobin";

            if (name.Contains("rbc") ||
                name.Contains("red blood"))
                return "rbc";

            if (name.Contains("wbc") ||
                name.Contains("white blood") ||
                name.Contains("leuco") ||
                name.Contains("leuko"))
                return "wbc";

            if (name.Contains("plt") ||
                name.Contains("platelet"))
                return "platelets";

            if (name.Contains("hct") ||
                name.Contains("haematocrit"))
                return "hematocrit";

            if (name.Contains("alp") ||
                name.Contains("alk phos"))
                return "alkaline phosphatase";

            if (name.Contains("tbil") ||
                name.Contains("t.bil"))
                return "bilirubin";

            if (name.Contains("chol") &&
                !name.Contains("hdl") &&
                !name.Contains("ldl"))
                return "cholesterol";

            if (name.Contains("trig"))
                return "triglycerides";

            if (name.Contains("gluc"))
                return "glucose";

            if (name.Contains("creat"))
                return "creatinine";

            if (name.Contains("neut"))
                return "neutrophils";

            if (name.Contains("lymph"))
                return "lymphocytes";

            if (name.Contains("mono"))
                return "monocytes";

            if (name.Contains("eosino"))
                return "eosinophils";

            if (name.Contains("baso"))
                return "basophils";

            return name;
        }
    }
}