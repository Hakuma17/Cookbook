// lib/models/recipe_step.dart

class RecipeStep {
  final int stepNumber;
  final String description;

  RecipeStep({
    required this.stepNumber,
    required this.description,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      return v is int ? v : int.tryParse(v.toString()) ?? 0;
    }

    String parseString(dynamic v) {
      if (v == null) return '';
      return v.toString();
    }

    return RecipeStep(
      stepNumber: parseInt(json['step_number']),
      description: parseString(json['description']),
    );
  }
}
