abstract final class AppStrings {
  static const spokenGuide =
      'Ứng dụng tự động đọc mệnh giá. Đưa tờ tiền ra khỏi camera để quét tờ tiếp theo.';
  static const appTitle = 'Nhận diện tiền Việt Nam';
  static const recognitionTitle = 'Nhận diện mệnh giá';
  static const simulationBanner =
      'Chrome: mô phỏng nhận diện; Android: camera và model TFLite.';
  static const cameraPlaceholder = 'Camera mô phỏng trên Chrome';
  static const cameraAlignHelp = 'Đưa một tờ tiền vào giữa khung và giữ yên.';
  static const cameraPermissionTitle = 'Quyền camera';
  static const settingsTitle = 'Tùy chọn';
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
      'Kết quả mô phỏng để thử giao diện và giọng đọc.';
  static const recognizedRealMessage = 'Kết quả đã được tự động đọc.';
  static const unclearTitle = 'Chưa rõ';
  static const unclearMessage =
      'Chưa rõ mệnh giá. Đưa một tờ tiền vào giữa khung, đủ sáng và giữ yên.';
  static const errorTitle = 'Có lỗi';
  static const errorMessage =
      'Không thể hoàn tất phiên quét mô phỏng. Hãy quét lại.';
  static const errorRealMessage =
      'Không thể hoàn tất phiên quét. Hãy quét lại.';
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
  static const vibration = 'Rung phản hồi';
  static const vibrationDetail = 'Rung khi có kết quả hoặc lỗi nhận diện.';
  static const speechRate = 'Tốc độ giọng đọc';
  static const slow = 'Chậm';
  static const normal = 'Vừa';
  static const fast = 'Nhanh';
  static const guideHeading = 'Cách sử dụng';
  static const guideStep3Detail =
      'Mệnh giá được hiện và đọc theo cài đặt âm thanh.';
  static const listenGuide = 'Nghe hướng dẫn';
  static const listenGuideMockNotice =
      'Chưa phát âm thanh. Thành viên 3 sẽ kết nối chức năng nghe hướng dẫn.';
}
