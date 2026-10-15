# Nhận diện tiền Việt Nam — giao diện mô phỏng

Ứng dụng gồm **4 màn hình mobile riêng** theo ảnh tham chiếu: Nhận diện, Quyền camera, Tùy chọn và Hướng dẫn. Trên Chrome máy tính, toàn bộ luồng điều hướng hiển thị trong khung điện thoại rộng 390 px, cao tối đa 844 px; trên điện thoại, ứng dụng dùng toàn bộ màn hình. Màn chính có nền xanh đậm, khung tờ tiền và nút vàng; các màn phụ dùng nền sáng.

> **Trạng thái:** Camera, nhận diện AI, đọc giọng nói, rung và quyền camera hệ thống **chưa được kết nối**. Mọi kết quả trong bản này là dữ liệu demo, được gắn nhãn “Kết quả mô phỏng”. Không dùng kết quả demo để xác định tiền thật.

## Chuẩn bị trên Windows

Cần Flutter **3.41 trở lên** (theo `pubspec.yaml`). Các ví dụ dùng **PowerShell**, với Flutter SDK hiện tại ở `D:\sdk_flutter\flutter`. Không cần thêm Flutter vào PATH để dùng các lệnh đầy đủ bên dưới.

- **Chrome:** Cài Google Chrome.
- **Android:** Cài Android Studio và các thành phần trong **Tools → SDK Manager**: Android SDK Platform theo yêu cầu của Flutter, Build-Tools, Platform-Tools, Command-line Tools, NDK/CMake khi công cụ build yêu cầu. Cài thêm Android Emulator nếu dùng máy ảo.
- Lần lấy thư viện hoặc build đầu tiên cần mạng để tải dependencies, Gradle và các thành phần Android còn thiếu.

Mỗi khi mở terminal mới, đặt lại biến `$flutter`. Nếu máy khác dùng vị trí SDK hoặc dự án khác, thay hai đường dẫn tương ứng:

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter doctor -v
& $flutter pub get
```

Dấu `&` dùng để gọi file `.bat` từ biến trong PowerShell. Chờ từng lệnh hoàn tất rồi chạy lệnh tiếp theo. Dùng mục Chrome hoặc Android bên dưới để chọn thiết bị.

## Chạy trên Chrome

Mở PowerShell và chạy:

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter pub get
& $flutter devices
& $flutter run -d chrome
```

Danh sách thiết bị cần có **Chrome (web)**. Flutter sẽ biên dịch và mở Chrome; giữ terminal mở trong lúc dùng ứng dụng. Khi xem trên máy tính, ứng dụng nằm trong khung mobile và chuyển qua lại giữa bốn màn hình.

Bản debug có mục thu gọn **Thử trạng thái mô phỏng** ở cuối màn nhận diện. Mở mục này rồi chọn **Thử thành công** để xem mệnh giá mẫu. Bản release chưa kết nối camera/AI nên nút Bắt đầu quét chỉ thông báo chức năng chưa sẵn sàng.

## Chạy trên Android

### 1. Kiểm tra công cụ Android

Mở PowerShell:

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter doctor -v
```

Xử lý các lỗi trong mục **Android toolchain** trước khi chạy. Nếu chưa chấp nhận giấy phép Android SDK, dùng lệnh sau rồi đọc và chấp nhận các giấy phép cần thiết:

```powershell
& $flutter doctor --android-licenses
& $flutter doctor -v
```

Sau đó chọn **điện thoại thật** hoặc **máy ảo Android**.

### 2a. Điện thoại Android qua USB

1. Trên điện thoại, bật **Tùy chọn nhà phát triển → Gỡ lỗi USB (USB debugging)**.
2. Kết nối bằng cáp USB có truyền dữ liệu, mở khóa điện thoại và chấp nhận hộp thoại cho phép gỡ lỗi từ máy tính.
3. Trên Windows, cài USB driver của hãng điện thoại nếu cần.
4. Chạy các lệnh sau. Thay `ID_THIET_BI` bằng ID của điện thoại Android trong kết quả `devices`, không chọn dòng Chrome hoặc Windows.

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter pub get
& $flutter devices

$deviceId = "ID_THIET_BI"
& $flutter run -d $deviceId
```

Flutter sẽ build, cài và mở ứng dụng trên điện thoại. Sau khi kết nối thành công, bật **TalkBack** trên điện thoại để kiểm tra nhãn đọc, thứ tự vuốt và thao tác kích hoạt nút.

### 2b. Máy ảo Android (Emulator)

Trong Android Studio, mở **Tools → Device Manager → Create Virtual Device**, chọn mẫu điện thoại, tải system image phù hợp và hoàn tất tạo máy ảo. Nhấn nút **Run** của máy ảo, đợi Android khởi động xong.

Khi máy ảo đã mở, chạy:

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter pub get
& $flutter devices

$deviceId = "ID_THIET_BI"
& $flutter run -d $deviceId
```

Thay `ID_THIET_BI` bằng ID của máy ảo từ `devices`, thường có dạng `emulator-5554`; dùng ID thực tế trên máy của bạn.

Nếu muốn mở một máy ảo đã tạo từ terminal, liệt kê và chọn ID như sau:

```powershell
& $flutter emulators

$emulatorId = "ID_MAY_AO"
& $flutter emulators --launch $emulatorId
```

Thay `ID_MAY_AO` bằng ID từ `emulators`. Đợi máy ảo khởi động rồi chạy lại `devices` và `run -d` như trên. **ID để khởi động máy ảo** và **ID thiết bị để chạy ứng dụng** có thể khác nhau.

### 3. Xuất APK debug để cài thử

Sau khi Android toolchain đã sẵn sàng:

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter pub get
& $flutter build apk --debug
```

APK tạo tại `build\app\outputs\flutter-apk\app-debug.apk`. Đây là bản debug để kiểm tra, chưa phải bản phát hành.

## Cập nhật giao diện và dừng chạy

Khi terminal vẫn đang chạy `run`, bấm phím trực tiếp vào terminal:

- `r`: hot reload sau khi sửa giao diện.
- `R` (Shift + R): hot restart, khởi động lại ứng dụng và đặt lại state trong bộ nhớ.
- `q`: kết thúc phiên chạy Flutter.
- **Ctrl + C**: ngắt lệnh nếu bị kẹt.

Để chạy lại, gọi `& $flutter run -d chrome` hoặc `& $flutter run -d $deviceId`. Khi đổi từ Chrome sang Android, dừng phiên cũ trước rồi chọn thiết bị mới.

## Xử lý lỗi thường gặp

### Flutter không tìm thấy hoặc vẫn dùng SDK cũ

Dùng `$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"` trong terminal hiện tại. Nếu VS Code còn trỏ SDK cũ, chọn **Flutter: Change SDK** trong Command Palette rồi chọn `D:\sdk_flutter\flutter`. Thư mục SDK là thư mục chứa `bin`.

### Lỗi shader: impellerc, runtime_effect.glsl, ink_sparkle.frag

SDK từng nằm trong đường dẫn có dấu và gây lỗi biên dịch shader. Dùng SDK mới không dấu tại `D:\sdk_flutter\flutter`, rồi chạy lại từ thư mục dự án:

```powershell
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter clean
& $flutter pub get
& $flutter run -d chrome
```

`clean` xóa file build và cấu hình sinh tự động; không xóa code trong `lib/`. Không cần chạy `clean` mỗi lần khởi động ứng dụng.

Nếu Gradle báo đường dẫn dự án chứa ký tự không ASCII khi build Android, đóng phiên chạy rồi chuyển dự án sang đường dẫn không dấu, không khoảng trắng, ví dụ `D:\projects\app_HoTroNguoiKhienThi`. Mở lại dự án ở vị trí mới, thay dòng `Set-Location` tương ứng và chạy lại `pub get`.

### Không thấy Chrome trong devices

Kiểm tra Chrome đã được cài, bật hỗ trợ web rồi kiểm tra lại:

```powershell
& $flutter config --enable-web
& $flutter devices
```

Nếu Flutter vẫn báo không tìm thấy file Chrome, đặt đường dẫn thực tế của Chrome cho terminal hiện tại. Ví dụ khi Chrome được cài ở vị trí sau:

```powershell
$env:CHROME_EXECUTABLE = "C:\Program Files\Google\Chrome\Application\chrome.exe"
& $flutter run -d chrome
```

### Không thấy thiết bị Android hoặc trạng thái unauthorized

Kiểm tra điện thoại đã mở khóa, USB debugging đã bật, cáp có truyền dữ liệu và đã chấp nhận hộp thoại gỡ lỗi. Với emulator, đợi máy ảo khởi động xong. Chạy lại `& $flutter devices` và xử lý các lỗi Android mà `doctor -v` báo.

### Waiting for another flutter command to release the startup lock

Kiểm tra các terminal đang chạy Flutter. Dừng lệnh cũ bị kẹt bằng **Ctrl + C**, hoặc chờ lệnh đang tải/build hoàn tất, rồi thử lại. Không chạy nhiều lệnh khởi động Flutter cùng lúc.

Thông báo `packages have newer versions incompatible with dependency constraints` sau `Got dependencies!` chỉ cho biết có bản dependency mới; không phải lỗi biên dịch.

Hướng dẫn chính thức: [thiết lập Chrome/Web](https://docs.flutter.dev/platform-integration/web/setup), [chạy Flutter Web](https://docs.flutter.dev/platform-integration/web/building), [thiết lập Android](https://docs.flutter.dev/platform-integration/android/setup), [chọn đường dẫn SDK](https://docs.flutter.dev/install/manual).

## Cách thử bốn màn hình

1. **Nhận diện:** Màn chính nền xanh đậm, nút Tùy chọn ở trên, khung căn tờ tiền và vùng kết quả. Ban đầu là “Sẵn sàng”, chưa có mệnh giá; nút Đọc lại chỉ bật khi có kết quả. Nhấn Bắt đầu quét để thử phiên mô phỏng.
2. **Quyền camera:** Chọn Quyền camera ở cuối màn chính hoặc Camera và quyền truy cập trong Tùy chọn. Thử Trong khi dùng ứng dụng, Chỉ lần này hoặc Không cho phép. Đây là giao diện mô phỏng, chưa xin quyền hệ thống.
3. **Tùy chọn:** Chọn Tùy chọn ở đầu màn chính. Thay đổi rung, tốc độ giọng đọc, tự động đọc kết quả. Giá trị được giữ khi chuyển màn trong cùng phiên. Nghe hướng dẫn mở màn Hướng dẫn; Về nhận diện quay lại màn chính.
4. **Hướng dẫn:** Có ba bước sử dụng và hai nút Nghe hướng dẫn, Bắt đầu nhận diện. Về Menu trở lại màn vừa mở Hướng dẫn; Bắt đầu nhận diện đưa về màn chính kể cả khi đi từ Tùy chọn.

Để xem trạng thái có mệnh giá như ảnh tham chiếu, mở **Thử trạng thái mô phỏng** ở cuối màn chính rồi chọn **Thử thành công**. Kết quả luôn ghi nhãn mô phỏng. Có thể thử Chưa rõ, Lỗi hoặc Quét lại để kiểm tra xóa kết quả cũ.

## Kiểm tra thay đổi giao diện

Đã chạy `dart analyze lib test` không có lỗi và `flutter test --no-pub` đạt **16/16**. Kiểm thử bao gồm điều hướng bốn màn, quay từ Hướng dẫn về Menu hoặc màn chính, quyền camera mô phỏng, khung mobile trên desktop, màn nhỏ, chữ phóng gấp đôi và chạm sát cả bốn cạnh của từng vùng tốc độ. Ba vùng Chậm/Vừa/Nhanh có chiều rộng bằng nhau, cao tối thiểu 64 px, kèm nhãn và trạng thái chọn cho trình đọc màn hình.

Có thể chạy lại kiểm tra và build bằng PowerShell tại thư mục dự án:

```powershell
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"
$dart = "D:\sdk_flutter\flutter\bin\cache\dart-sdk\bin\dart.exe"

& $dart format --output=none --set-exit-if-changed lib test
& $flutter analyze
& $flutter test
& $flutter build web --debug
& $flutter build apk --debug
```

Lệnh build APK cần Android toolchain đã được cấu hình. Kiểm thử widget không thay thế kiểm tra thực tế trên Chrome, Android hoặc TalkBack.

## Phần UI đã hoàn thành và giới hạn mô phỏng

| Thành phần | Hiện có | Chưa có |
| --- | --- | --- |
| Nhận diện | Khung căn chỉnh, vùng mệnh giá lớn, 5 trạng thái sẵn sàng/đang quét/đã nhận diện/chưa rõ/lỗi, cảnh báo và hướng dẫn điều chỉnh bằng chữ | Camera stream, YOLO/TFLite, logic nhiều frame, đọc kết quả tự động |
| Phiên quét | Bắt đầu/quét lại, xóa kết quả cũ, phản hồi giao diện và thông báo mock | Điều phối phiên thật, chống đọc lặp, phản hồi bằng giọng nói |
| Đọc lại | Chỉ bật khi có kết quả, hiện thông báo mock | TTS thật |
| Quyền camera | Giải thích mục đích, đồng ý/từ chối mô phỏng, lối thoát khi từ chối | Xin quyền Android thật hoặc mở cài đặt hệ thống |
| Cài đặt | Công tắc tự đọc/rung và tốc độ giọng nói, giữ trong bộ nhớ khi chuyển màn | Kết nối TTS/rung, lưu xuống thiết bị |
| Hướng dẫn | Ba bước ngắn, nút nghe và điều hướng | Phát âm thanh hướng dẫn |

Ảnh phác thảo cho thấy mệnh giá ngay khi mở ứng dụng, phiên tự bắt đầu sau 15 giây và cài đặt được lưu tự động. Bản UI này **không hiển thị mệnh giá giả trước khi chọn demo**, **không chạy bộ đếm thời gian** và **không lưu cài đặt sau khi đóng app**; các quy tắc phiên và lưu trữ cần được nhóm thống nhất trước khi tích hợp.

## File thuộc phần việc TV1

- Khởi chạy, theme, chuỗi và hằng số UI: `lib/main.dart`, `lib/app.dart`, `lib/core/constants/`, `lib/core/theme/`.
- Hợp đồng trình bày tạm: `lib/core/models/recognition_ui_state.dart`, `lib/core/models/app_settings.dart`.
- Bốn màn hình: `lib/screens/recognition/`, `lib/screens/permission/`, `lib/screens/settings/`, `lib/screens/guide/`.
- Widget dùng chung: `lib/widgets/accessible_button.dart`, `camera_frame.dart`, `denomination_card.dart`, `recognition_status.dart`, `mobile_page.dart`.
- Dữ liệu và điều khiển demo chỉ ở debug: `lib/debug/`.
- Widget tests: `test/`. Cấu hình Web: `web/` và `.metadata`. Cấu hình Android tối thiểu: `android/` (package ID tạm `com.example.app_ho_tro_nguoi_khiem_thi`; đổi theo tên miền của nhóm trước khi phát hành).

`app_constants.dart` chỉ chứa kích thước/khoảng cách UI; không chứa ngưỡng confidence hoặc quy tắc AI. Không có dependency cho camera, TFLite, TTS, rung hoặc lưu trữ.

## Điểm nối cho TV2 và TV3

Đây là **hợp đồng trình bày tạm**, chưa phải `RecognitionController` nghiệp vụ. Nhóm cần xác nhận kiểu mệnh giá, quy tắc chuyển trạng thái và nguồn phát thông báo trước khi thay demo.

- `RecognitionScreen` nhận `RecognitionUiState` từ ngoài. `RecognitionUiStatus` có `ready`, `scanning`, `recognized`, `unclear`, `error`; `denomination` là `String?`, `guidance` là câu hướng dẫn tùy chọn, `isMock` cho biết kết quả demo. `hasResult` chỉ đúng khi trạng thái `recognized` có mệnh giá không rỗng. Khi TV2 truyền `isMock: false`, câu trạng thái và nhãn mệnh giá dùng nội dung cho dữ liệu thật; cần đồng thời truyền `cameraPreview` để thay placeholder. `lib/app.dart` hiện giữ state bằng `ValueNotifier` và cung cấp callback `onStartScanning`, `onReplayResult`, `onResetScan`.
- **TV2:** Nối luồng nhận diện thật vào `onStartScanning`/`onResetScan` và đẩy state/result mới từ controller hoặc notifier của nhóm. Xóa mệnh giá cũ khi bắt đầu phiên mới; truyền cảnh báo điều chỉnh qua `guidance`. Thay placeholder bằng `cameraPreview` của `RecognitionScreen`; `CameraFrame` chỉ vẽ bốn góc, không xử lý ảnh. Thay hành vi mô phỏng ở `onOpenPermission` và các callback `CameraPermissionScreen` bằng luồng xin quyền thật. Không đưa camera/AI trực tiếp vào widget trình bày.
- **TV3:** Nối `onReplayResult` với TTS thật, chỉ phát khi `hasResult`. Dùng `AppSettings.autoReadEnabled`, `vibrationEnabled`, `speechRate` và các callback cập nhật ở `SettingsScreen` để kết nối tự đọc/rung/tốc độ. Nối `GuideScreen.onListen` với đọc hướng dẫn. Phản hồi giọng nói khi bắt đầu phiên, có kết quả hoặc cần điều chỉnh phải theo điều phối phiên thật do nhóm thống nhất; hiện các điểm này chỉ có chữ/SnackBar.
- `lib/debug/mock_recognition_scenarios.dart` và `recognition_demo_controls.dart` là dữ liệu/công cụ thử riêng, chỉ được gắn vào cây UI khi `kDebugMode`. Loại chúng khỏi luồng sản phẩm khi thay kết quả thật.

## Kiểm tra và checklist bàn giao

Kiểm tra tự động gần nhất: phân tích code không có lỗi, **16/16 widget test đạt**. Các test nằm trong `test/recognition_widgets_test.dart`, `test/app_navigation_test.dart`, `test/mobile_flow_test.dart` và `test/speech_rate_touch_test.dart`.

**Chưa xác nhận chạy ứng dụng trên thiết bị/emulator Android và TalkBack thực tế.** Thực hiện các bước Android ở trên rồi hoàn tất checklist sau. Dùng `doctor -v` và `devices` để kiểm tra trạng thái máy hiện tại; thông tin giấy phép hoặc thiết bị có thể thay đổi.

- [ ] Mở cả bốn màn hình, quay lại bằng nút trong ứng dụng và nút Back của Android; không crash.
- [ ] Ở màn hình chính, Đọc lại bị vô hiệu hóa khi chưa có kết quả; bật sau “Thử thành công”; Quét lại xóa kết quả ngay.
- [ ] “Thử chưa rõ” và “Thử lỗi” hiển thị cảnh báo bằng chữ và không giữ mệnh giá cũ.
- [ ] Từ chối quyền mô phỏng vẫn quay lại hoặc tiếp tục được; không xuất hiện hộp thoại xin quyền hệ thống.
- [ ] Đổi cả ba cài đặt, rời màn hình rồi quay lại; giá trị giữ trong phiên, không kỳ vọng giữ sau khi đóng app.
- [ ] Bật TalkBack, vuốt theo thứ tự đọc tự nhiên qua tiêu đề, trạng thái, khung, mệnh giá và các nút; nhãn kết quả demo chỉ đọc một lần. Kích hoạt nút theo thao tác TalkBack chuẩn.
- [ ] Tăng cỡ chữ hệ thống đến mức lớn, thử màn hình nhỏ và xoay màn hình; nội dung vẫn cuộn được, nút không bị cắt.
- [ ] Thử Nghe hướng dẫn/Đọc lại và xác nhận thông báo nói rõ chưa phát âm thanh thật.

Các mục kiểm tra trên thiết bị là việc còn lại; APK build thành công không chứng minh hành vi Android/TalkBack thực tế.
