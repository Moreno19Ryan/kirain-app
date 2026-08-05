class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.isEmergencyFund,
    required this.priorityOrder,
    this.targetDate,
  });

  final String id;
  final String name;
  final num targetAmount;
  final num currentAmount;
  final bool isEmergencyFund;
  final int priorityOrder;
  final DateTime? targetDate;

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0, 1) : 0;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String,
      name: json['name'] as String,
      targetAmount: json['target_amount'] as num,
      currentAmount: json['current_amount'] as num,
      isEmergencyFund: json['is_emergency_fund'] as bool,
      priorityOrder: json['priority_order'] as int,
      targetDate: json['target_date'] == null
          ? null
          : DateTime.parse(json['target_date'] as String),
    );
  }
}
