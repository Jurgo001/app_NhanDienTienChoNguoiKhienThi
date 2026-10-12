abstract final class AppStrings {
  static const appTitle = 'Nhận diện tiền Việt Nam';
  static const recognitionTitle = 'Nhận diện mệnh giá';
  static const simulationBanner =
      'Bản giao diện mô phỏng. Chưa kết nối camera, AI, giọng nói hoặc rung.';
  static const cameraPlaceholder = 'Camera mô phỏng — chưa kết nối camera';
  static const cameraAlignHelp = 'Đưa một tờ tiền vào giữa khung và giữ yên.';
  static const cameraPermissionTitle = 'Quyền camera';
  static const settingsTitle = 'Cài đặt';
  static const guideTitle = 'Hướng dẫn';
  static const resultTitle = 'Mệnh giá';
  static const mockResultLabel = 'Kết quả mô phỏng';
  static const noResult = 'Chưa có kết quả';
  static const scanningNoResult = 'Đang chờ kết quả mô phỏng';
  static const scanningNoResultReal = 'Đang chờ kết quả';
  static const readyTitle = 'Sẵn sàng';
  static const readyMessage = 'Đưa một tờ tiền vào khung, sau đó bắt đầu quét.';
  static const scanningTitle = 'Đang quét';
  static const scanningMessage =
      'Đang mô phỏng phiên quét. Dùng công cụ demo để thử kết quả.';
  static const scanningRealMessage = 'Đang quét. Giữ yên tờ tiền trong khung.';
  static const recognizedTitle = 'Đã nhận diện';
  static const recognizedMessage =
      'Đây là kết quả giả để kiểm tra giao diện. Chưa phát âm thanh.';
  static const recognizedRealMessage = 'Đã có kết quả. Chọn Đọc lại khi cần.';
  static const unclearTitle = 'Chưa rõ';
  static const unclearMessage =
      'Chưa rõ mệnh giá. Đưa một tờ tiền vào giữa khung, đủ sáng và giữ yên.';
  static const errorTitle = 'Có lỗi';
  static const errorMessage =
      'Không thể hoàn tất phiên quét mô phỏng. Hãy quét lại.';
  static const errorRealMessage =
      'Không thể hoàn tất phiên quét. Hãy quét lại.';
  static const startScan = 'Bắt đầu quét';
  static const scanAgain = 'Quét lại';
  static const replay = 'Đọc lại';
  static const replayMockNotice =
      'Đọc lại đang mô phỏng. Thành viên 3 sẽ kết nối giọng nói thật.';
  static const scanMockNotice =
      'Đã bắt đầu phiên quét mô phỏng. Phản hồi giọng nói sẽ được kết nối sau.';
  static const resetMockNotice =
      'Đã xóa kết quả cũ và bắt đầu phiên mới (mô phỏng).';
  static const scanUnavailableNotice =
      'Chưa kết nối camera và nhận diện. Hãy chạy bản debug để thử giao diện mô phỏng.';
  static const demoTitle = 'Công cụ demo (chỉ bản debug)';
  static const demoDescription =
      'Các nút sau chỉ đổi trạng thái giao diện; không chạy camera hoặc AI.';
  static const demoRecognized = 'Thử thành công';
  static const demoUnclear = 'Thử chưa rõ';
  static const demoError = 'Thử lỗi';
  static const mockDenomination = '100.000 đồng';
  static const permissionHeading = 'Camera dùng để làm gì?';
  static const permissionDescription =
      'Ứng dụng sẽ dùng camera để đưa tờ tiền vào khung và nhận diện mệnh giá.';
  static const permissionSimulation =
      'Hiện tại đây chỉ là màn hình mô phỏng quyền. Nút bên dưới không xin quyền hệ thống hoặc mở camera.';
  static const permissionSteps =
      'Khi có camera thật: đặt một tờ tiền trước camera, giữ yên và chọn Bắt đầu quét.';
  static const grantCamera = 'Cấp quyền camera';
  static const permissionApprovedMockNotice =
      'Đã đồng ý trong bản mô phỏng. Chưa cấp quyền camera hệ thống.';
  static const denyCamera = 'Từ chối mô phỏng';
  static const permissionDeniedTitle = 'Đã từ chối trong bản mô phỏng';
  static const permissionDeniedMessage =
      'Bạn vẫn có thể quay lại hoặc tiếp tục xem giao diện nhận diện mô phỏng.';
  static const continueWithoutCamera = 'Tiếp tục bản mô phỏng';
  static const settingsMockNotice =
      'Đây là cấu hình UI mô phỏng. Chưa kết nối TTS hoặc rung; thay đổi chỉ được giữ trong phiên chạy và không lưu sau khi đóng ứng dụng.';
  static const autoRead = 'Tự động đọc kết quả';
  static const autoReadDetail =
      'Sẽ áp dụng khi thành viên 3 kết nối giọng nói.';
  static const vibration = 'Rung phản hồi';
  static const vibrationDetail = 'Sẽ áp dụng khi thành viên 3 kết nối rung.';
  static const speechRate = 'Tốc độ giọng nói';
  static const slow = 'Chậm';
  static const normal = 'Vừa';
  static const fast = 'Nhanh';
  static const guideHeading = 'Cách sử dụng';
  static const guideStep1Title = 'Đưa tờ tiền vào khung';
  static const guideStep1Detail = 'Chỉ đưa một tờ tiền vào giữa khung.';
  static const guideStep2Title = 'Bắt đầu quét';
  static const guideStep2Detail = 'Nhấn Bắt đầu quét và giữ yên điện thoại.';
  static const guideStep3Title = 'Xem hoặc nghe kết quả';
  static const guideStep3Detail =
      'Mệnh giá sẽ hiện trên màn hình. Giọng nói sẽ được kết nối sau.';
  static const guideStep4Title = 'Đọc lại khi cần';
  static const guideStep4Detail = 'Nút Đọc lại chỉ bật khi có kết quả.';
  static const guideStep5Title = 'Quét tờ tiền khác';
  static const guideStep5Detail = 'Nhấn Quét lại để xóa kết quả cũ.';
  static const listenGuide = 'Nghe hướng dẫn';
  static const listenGuideMockNotice =
      'Chưa phát âm thanh. Thành viên 3 sẽ kết nối chức năng nghe hướng dẫn.';
  static const returnToRecognition = 'Về màn hình nhận diện';
}
