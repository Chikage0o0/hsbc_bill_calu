import 'package:flutter/material.dart';
import 'messages/basic.pb.dart';

class DatePickerFieldsLayout extends StatelessWidget {
  const DatePickerFieldsLayout({super.key});

  void onDateChanged(DateTime date, DateType dateType) {
    DateRequest(
            date: Date(year: date.year, month: date.month, day: date.day),
            dateType: dateType)
        .sendSignalToRust();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20.0, // 水平方向的间距
      runSpacing: 20.0, // 垂直方向的间距
      children: [
        SizedBox(
          width: 300, // 固定宽度
          child: _DatePickerField(
              label: "开始日期",
              onChanged: (date) => onDateChanged(date, DateType.Start)),
        ),
        SizedBox(
          width: 300, // 固定宽度
          child: _DatePickerField(
              label: "结束日期",
              onChanged: (date) => onDateChanged(date, DateType.End)),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatefulWidget {
  final String label; // 新增label参数
  final Function(DateTime)? onChanged; // 新增onChanged参数

  const _DatePickerField({required this.label, this.onChanged}); // 构造函数传入label

  @override
  _DatePickerFieldState createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<_DatePickerField> {
  // 控制TextField的内容
  final TextEditingController _controller = TextEditingController();

  // 打开日期选择器并更新输入框内容
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale("zh", "CN"),
    );
    if (picked != null) {
      setState(() {
        // 将选中的日期更新到输入框中
        _controller.text = "${picked.toLocal()}".split(' ')[0];
        // 调用onChanged回调
        widget.onChanged?.call(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
      children: [
        // 在输入框上方显示传入的label
        Text(
          widget.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8), // 添加一点间距
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: '选择日期',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          readOnly: true, // 设置为只读，防止手动输入
          onTap: () => _selectDate(context), // 点击时弹出日期选择器
        ),
      ],
    );
  }
}
