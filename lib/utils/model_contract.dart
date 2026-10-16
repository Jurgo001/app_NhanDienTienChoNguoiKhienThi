import 'denomination_mapper.dart';

/// Từ chối model khác hợp đồng để tránh đọc nhầm thứ tự nhãn.
abstract final class ModelContract {
  static void validate(List<int> input, List<int> output) {
    final nchw = input.length == 4 && input[1] == 3 && input[2] == input[3];
    final nhwc = input.length == 4 && input[3] == 3 && input[1] == input[2];
    final channels = 4 + DenominationMapper.classLabels.length;
    if (input.length != 4 ||
        input[0] != 1 ||
        (!nchw && !nhwc) ||
        input.any((v) => v <= 0)) {
      throw StateError('Input model cần [1,3,H,H] hoặc [1,H,H,3]: $input');
    }
    if (output.length != 3 ||
        output[0] != 1 ||
        (output[1] != channels && output[2] != channels) ||
        output.any((v) => v <= 0)) {
      throw StateError('Output model cần $channels kênh cho 18 nhãn: $output');
    }
  }
}
