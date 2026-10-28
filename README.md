# Nhận diện tiền Việt Nam

Ứng dụng hỗ trợ người khiếm thị với **4 màn mobile riêng**: Nhận diện, Quyền camera, Tùy chọn và Hướng dẫn. Trên máy tính, các màn nằm trong khung 390 × 844 px; trên điện thoại ứng dụng dùng toàn màn hình.

| Nền tảng | Chức năng |
| --- | --- |
| **Android, API 24 trở lên** | Camera sau → model TFLite trên điện thoại → xác nhận 3 frame cùng mệnh giá → hiển thị, đọc tiếng Việt và rung theo cài đặt. |
| **Chrome** | Thử giao diện, điều hướng, lưu cài đặt và giọng đọc của trình duyệt. Bấm Bắt đầu quét sẽ nhận kết quả tự động **mô phỏng**, có nhãn và lời đọc phân biệt. Web chưa chạy model/camera nhận diện thật. |

## Chạy trên Chrome

Dùng PowerShell, chạy từng lệnh:

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter pub get
& $flutter devices
& $flutter run -d chrome
```

Nếu danh sách chưa có Chrome: cài Google Chrome, chạy `& $flutter config --enable-web`, mở terminal mới và kiểm tra lại `devices`.

Giọng đọc web phụ thuộc giọng tiếng Việt mà Windows/Chrome cung cấp. Nếu có thông báo thiếu giọng, cài giọng vi-VN và bấm **Thử lại âm thanh / cài đặt**. Vẫn có thể kiểm tra giao diện khi giọng chưa sẵn sàng.

## Chạy trên Android

### Chuẩn bị

- Flutter **3.41 trở lên**; máy hiện tại dùng SDK tại `D:\sdk_flutter\flutter`.
- Android Studio, Android SDK, Platform-Tools, Command-line Tools và NDK theo yêu cầu `flutter doctor -v`. Lần build đầu cần mạng để tải phần còn thiếu.
- JDK tương thích Gradle 8.14. **JDK 25 đi kèm Android Studio trên máy hiện tại không tương thích.** Máy có JDK 23 tại `C:\Program Files\Java\jdk-23`.
- Điện thoại Android 7.0/API 24 trở lên, camera và giọng đọc tiếng Việt. Với ứng dụng nhận diện, nên thử bằng điện thoại thật.

Máy hiện tại đã được cấu hình Flutter dùng JDK 23. Nếu cần thiết lập lại, chọn JDK **một lần**:

```powershell
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"
& $flutter config --jdk-dir="C:\Program Files\Java\jdk-23"
& $flutter doctor -v
& $flutter doctor --android-licenses
```

`flutter config --jdk-dir` lưu lựa chọn JDK cho những lần chạy Flutter tiếp theo, kể cả project khác. Trên máy khác, thay bằng đường dẫn JDK tương thích đã cài. Đọc và chấp nhận các giấy phép SDK trong terminal nếu đồng ý.

### Điện thoại qua USB

1. Bật **Tùy chọn nhà phát triển → Gỡ lỗi USB**.
2. Cắm cáp truyền dữ liệu, mở khóa và chấp nhận hộp thoại cho phép gỡ lỗi.
3. Chạy `devices`, lấy ID dòng **Android**, thay `ID_DIEN_THOAI` bên dưới:

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter pub get
& $flutter devices
& $flutter run -d ID_DIEN_THOAI -t lib/main.dart
```

Khi mở màn hình nhận diện, ứng dụng tự xin quyền camera nếu cần, khởi chạy camera/mô hình và hướng dẫn đưa một tờ tiền vào khung. Khi kết quả ổn định, ứng dụng tự đọc mệnh giá một lần và rung nếu bật. Đưa tờ tiền ra khỏi camera để nhận diện lượt tiếp theo; cùng mệnh giá vẫn được đọc lại sau khi xác nhận tờ trước đã rời khung.

Nếu đã chặn quyền: mở **Quyền camera → Mở cài đặt ứng dụng**, cấp lại quyền rồi quay về màn hình nhận diện; camera sẽ tự khởi động lại.

Nếu cần máy ảo: tạo **một** thiết bị trong Android Studio → Device Manager và mở nó trước khi chạy `devices`. Không cần ổ đĩa ảo R:/S:, không cần tạo hai máy ảo. Camera/giọng/rung trên máy ảo có thể khác điện thoại thật.

### Build APK

Sau khi chọn đúng JDK và hoàn tất chuẩn bị:

```powershell
& $flutter build apk --debug
# APK: build\app\outputs\flutter-apk\app-debug.apk

powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_release.ps1
# APK: build\app\outputs\flutter-apk\app-release.apk
```

Với đường dẫn có dấu hiện tại, script release tạo bản sao source trong thư mục TEMP không dấu, build rồi chép APK về đúng đường dẫn trên và dọn bản sao. Không tạo ổ ảo hoặc di chuyển project. Nếu SDK nằm nơi khác, thêm tham số -FlutterSdk "C:\src\flutter". SDK Flutter cũng cần nằm trong thư mục không dấu.

Bản release hiện dùng khóa debug để chạy/nộp bài nội bộ. Cần cấu hình khóa ký riêng trước khi phát hành lên cửa hàng. Luồng nhận diện Android hoạt động ở cả debug và release; không bị chặn bởi `kDebugMode`.

### Dừng ứng dụng

Trong terminal đang chạy `flutter run`: nhấn **q**. Nếu lệnh bị kẹt, nhấn **Ctrl+C**. Dừng phiên Flutter trước khi chạy lệnh khác. Có thể đóng cửa sổ Chrome hoặc ứng dụng Android sau đó.

## Cài đặt và khả năng tiếp cận

- Ứng dụng luôn tự đọc kết quả và hướng dẫn bằng giọng nói. Chỉ cấu hình rung phản hồi và tốc độ đọc (Chậm/Vừa/Nhanh) được lưu qua SharedPreferences.
- Ba tốc độ là **ba vùng chạm bằng nhau**, mỗi vùng cao tối thiểu 64 px; chạm được cả khoảng trống quanh chữ.
- **Nghe hướng dẫn** dùng TTS thật với tốc độ đã chọn.
- Khi mở màn phụ hoặc đưa ứng dụng xuống nền: dừng camera và phản hồi. Quay lại màn nhận diện sẽ tiếp tục phiên đang quét.
- Kết quả từ phiên cũ bị bỏ qua sau khi chuyển màn hoặc chuyển ứng dụng xuống nền.
- Hướng dẫn thiếu sáng, quá gần/xa, nhiều tờ và giữ yên được hiển thị; hướng dẫn ổn định được đọc với khoảng cách tối thiểu 3,5 giây khi bật tự động đọc.
- Nếu thiếu giọng/engine, giao diện vẫn mở và cho thử lại âm thanh. Trên Android, vào **Cài đặt → Chuyển văn bản thành giọng nói** để cài giọng tiếng Việt; kiểm tra âm lượng phương tiện. Nhận diện được xử lý trên máy; tải giọng offline nếu cần dùng âm thanh không có mạng.

## Model và cấu trúc kết nối

Asset đã có sẵn và được khai báo trong `pubspec.yaml`:

```text
assets/models/best_float32.tflite
input: float32 [1, 3, 416, 416]
output: float32 [1, 22, 3549]
18 lớp = 9 mệnh giá × 2 mặt
```

Không cần chép thêm `best.pt`, ONNX hoặc cài TensorFlow vào điện thoại. `flutter pub get` lấy các package Dart cần thiết.

```text
main.dart → MoneyRecognitionApp
  → ScanSession (token phiên, tạm dừng, tự quét lại)
    → NativeScanBackend
      → CameraService → MoneyDetector
        → ImageConverter → TFLite isolate → YoloDecoder / NMS
    → RecognitionController
      → RecognitionScreen + SpeechService + HapticService
  → SettingsController → SettingsService
```

Trên Web, conditional import chọn `WebScanBackend`, tránh đưa `dart:ffi` vào bundle.

| Thành phần | File chính |
| --- | --- |
| TV1 – giao diện | `lib/screens/`, `lib/widgets/`, `lib/app.dart` |
| TV2 – camera/model | `lib/services/camera_service.dart`, `money_detector.dart`, `lib/utils/` |
| TV3 – điều phối/phản hồi | `lib/controllers/`, `speech_service.dart`, `haptic_service.dart`, `settings_service.dart` |
| Chọn backend | `lib/services/scan_backend_factory.dart`, `scan_backend_native.dart`, `scan_backend_web.dart` |
| Tương thích plugin Android | `android/plugin-compatibility.gradle` |

Tiền xử lý dùng chung cho test và worker: xoay theo hướng thiết bị, RGB/255, letterbox giữ tỷ lệ với viền 114, NCHW; decoder bỏ viền khi quy đổi box. `MoneyDetector(useLetterbox: false)` hỗ trợ đối chiếu cách resize khác nếu pipeline huấn luyện yêu cầu. Cần dùng bộ ảnh validation để xác nhận lựa chọn và hiệu chỉnh ngưỡng 0.78; kiểm tra tensor/mapping không chứng minh độ chính xác trên tiền thật.

## Kiểm thử

```powershell
& $flutter test
& "D:\sdk_flutter\flutter\bin\dart.bat" analyze lib test
& $flutter build web
```

Dùng `dart analyze` nếu `flutter analyze` trên Windows báo lỗi LSP với đường dẫn có dấu. Project đã bật tùy chọn Gradle hỗ trợ thư mục hiện tại có dấu và đã build thử thành công. Nếu công cụ Android/shader trên máy khác vẫn báo lỗi đường dẫn, dùng thư mục không dấu như `D:\projects\app_HoTroNguoiKhienThi` và mở lại project; không cần tạo ổ ảo.

Các test bao gồm luồng bốn màn, cài đặt lưu/đổi nhanh, 3 frame ổn định, callback muộn, timer, lifecycle, tiền xử lý/stride/xoay/letterbox, decoder/NMS, metadata của asset và hủy lời đọc cũ. Xem kết quả build/test cuối tại [INTEGRATION_FIXES.md](INTEGRATION_FIXES.md).

**Còn cần nghiệm thu trên điện thoại:** camera/TFLite thực tế, TalkBack, giọng/rung, chuyển nền và độ chính xác bằng ảnh tiền chưa dùng khi train. Máy kiểm thử hiện chưa có Android kết nối; build và unit/widget test không thay thế các bước này.

## Màn test riêng của từng thành viên

Chỉ chạy từng lệnh một trên Android; nhấn `q` trước khi đổi màn:

```powershell
& $flutter run -d ID_DIEN_THOAI -t lib/main_detector_test.dart
& $flutter run -d ID_DIEN_THOAI -t lib/main_tts_test.dart
& $flutter run -d ID_DIEN_THOAI -t lib/main_haptic_test.dart
& $flutter run -d ID_DIEN_THOAI -t lib/main_settings_test.dart
```

Màn TV2 riêng có công tắc MOCK phục vụ chẩn đoán; app chính Android luôn dùng model thật. Báo cáo [INTEGRATION_REVIEW.md](INTEGRATION_REVIEW.md) ghi lại hiện trạng **trước khi sửa**.
