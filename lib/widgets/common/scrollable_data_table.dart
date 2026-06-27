import 'package:flutter/material.dart';

class ScrollableDataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final double height;
  final String emptyLabel;

  const ScrollableDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.height = 260,
    this.emptyLabel = 'No data available',
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final resolvedHeight = height.clamp(220.0, screenHeight * 0.55);

    if (rows.isEmpty) {
      return Container(
        height: resolvedHeight,
        alignment: Alignment.center,
        child: Text(
          emptyLabel,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      height: resolvedHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(Colors.red.shade50),
              columns: columns
                  .map(
                    (label) => DataColumn(
                      label: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: row.map((cell) => DataCell(cell)).toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

