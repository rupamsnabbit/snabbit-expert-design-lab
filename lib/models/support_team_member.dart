class SupportTeamMember{
  final String? name;
  final String? role;
  final String? phoneNumber;

  const SupportTeamMember({
    this.name,
    this.role,
    this.phoneNumber,
  });

  // Factory constructor to create a SupportTeamMember from a JSON map
  factory SupportTeamMember.fromJson(Map<String, dynamic> json) {
    return SupportTeamMember(
      name: json['name'],
      role: json['role'],
      phoneNumber: json['phone_number'], // Assuming snake_case for JSON key
    );
  }

  // Method to convert a SupportTeamMember object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      'phone_number': phoneNumber, // Assuming snake_case for JSON key
    };
  }
}