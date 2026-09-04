class ApiResponse<T> {
  final bool isSuccess;
  final String status;
  final String message;
  final T? data;
  final dynamic errors;
  final int statusCode;

  ApiResponse({
    required this.isSuccess,
    required this.status,
    required this.message,
    this.data,
    this.errors,
    required this.statusCode,
  });

  factory ApiResponse.success({
    required T data,
    String message = 'Berhasil',
    String status = 'success',
    int statusCode = 200,
  }) {
    return ApiResponse<T>(
      isSuccess: true,
      status: status,
      message: message,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error({
    required String message,
    String status = 'error',
    dynamic errors,
    int statusCode = 400,
  }) {
    return ApiResponse<T>(
      isSuccess: false,
      status: status,
      message: message,
      errors: errors,
      statusCode: statusCode,
    );
  }
}
