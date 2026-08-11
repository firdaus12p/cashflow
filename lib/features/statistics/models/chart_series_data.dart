class ChartSeriesData {
  const ChartSeriesData({
    required this.title,
    required this.subtitle,
    required this.legend,
    required this.labels,
    required this.values,
  });

  final String title;
  final String subtitle;
  final String legend;
  final List<String> labels;
  final List<double> values;
}
