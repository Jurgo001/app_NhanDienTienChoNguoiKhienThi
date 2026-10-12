# Nhận diện tiền Việt Nam — giao diện mô phỏng

Phần việc **Thành viên 1 (UI/UX và Navigation)** của ứng dụng hỗ trợ người khiếm thị nhận diện mệnh giá tiền Việt Nam. Ảnh phác thảo trong yêu cầu được dùng để định hướng màu xanh đậm, vàng và bốn luồng chính. Bố cục hiện tại là bản Material dành cho điện thoại, ưu tiên chữ rõ, nút lớn và cuộn được khi tăng cỡ chữ; đây chưa phải bản đối chiếu Figma.

> **Trạng thái:** Camera, nhận diện AI, đọc giọng nói, rung và quyền camera hệ thống **chưa được kết nối**. Mọi kết quả trong bản này là dữ liệu demo, được gắn nhãn “Kết quả mô phỏng”. Không dùng kết quả demo để xác định tiền thật.

## Cài đặt và chạy

Yêu cầu Flutter **3.41 trở lên** (theo `pubspec.yaml`). Để thử trên Web cần Chrome; để chạy Android cần Android SDK và điện thoại hoặc emulator. Tại thư mục gốc repository:

```powershell
flutter doctor
flutter pub get
flutter devices
flutter run 
flutter run -d chrome
```

`flutter run -d chrome` mặc định chạy bản debug và hiện **Công cụ demo** ở cuối màn hình nhận diện. Trong bản release khi chưa tích hợp TV2, nút Bắt đầu quét chỉ báo rằng camera/nhận diện chưa kết nối; ứng dụng không treo ở trạng thái quét giả. Có thể kiểm tra tĩnh và build Web/APK debug bằng:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build web --debug
```

Trên môi trường Windows của nhóm, đường dẫn chứa dấu tiếng Việt từng gây lỗi cho một số lệnh Flutter/Gradle. Nếu gặp lại, có thể tạo ổ đĩa tạm bằng `subst` rồi chạy từ đường dẫn ASCII. Ví dụ cho máy đã dùng để kiểm tra:

```powershell
subst R: "D:\nam4 kì1\app_HoTroNguoiKhienThi"
subst S: "D:\nam4 kì1\flutter\flutter"
Set-Location R:\
S:\bin\flutter.bat pub get
S:\bin\flutter.bat run -d chrome
```

Thay hai đường dẫn bằng vị trí thực tế trên máy khác. Khi không còn dùng, chạy `subst R: /D` và `subst S: /D`.

## Chạy thử trên Chrome

Chạy `flutter run -d chrome` từ thư mục gốc. Flutter mở Chrome ở chế độ debug; giữ cửa sổ PowerShell để xem lỗi, nhấn `r` để hot reload hoặc `q` để dừng. Nếu lệnh gặp lỗi vì đường dẫn có dấu tiếng Việt, dùng hai ổ đĩa tạm `R:` và `S:` trong ví dụ trên rồi chạy `S:\bin\flutter.bat run -d chrome` tại `R:\`.

Trên Chrome, thử bốn màn hình và các nút trong **Công cụ demo** theo mục dưới. Đây chỉ là giao diện mô phỏng: không có camera, AI, âm thanh hay rung thật. Kiểm tra trên Chrome không thay cho thử TalkBack trên Android.

Để chạy Android về sau, kết nối điện thoại hoặc mở emulator, kiểm tra ID bằng `flutter devices`, rồi chạy `flutter run -d ID_THIET_BI`.

## Cách thử bốn màn hình

1. **Nhận diện (màn hình chính):** Ban đầu hiển thị “Sẵn sàng”, placeholder “Camera mô phỏng — chưa kết nối camera”, khung căn chỉnh và “Chưa có kết quả”. Nút **Đọc lại** bị vô hiệu hóa. Nhấn **Bắt đầu quét** để vào trạng thái “Đang quét”.
2. **Các trạng thái demo:** Cuộn đến **Công cụ demo (chỉ bản debug)**. Chọn **Thử thành công** để thấy “100.000 đồng” có nhãn kết quả mô phỏng và bật **Đọc lại**. Chọn **Thử chưa rõ** hoặc **Thử lỗi** để xem cảnh báo bằng chữ. Nhấn **Quét lại** để xóa mệnh giá cũ, bắt đầu phiên quét mô phỏng mới. **Đọc lại** chỉ hiện thông báo mô phỏng, không phát tiếng.
3. **Quyền camera:** Từ màn hình chính chọn **Quyền camera**. **Cấp quyền camera** chỉ giả lập đồng ý và trở về màn hình chính; không xuất hiện hộp thoại hệ thống. **Từ chối mô phỏng** hiển thị hướng dẫn; chọn **Tiếp tục bản mô phỏng** hoặc nút quay lại để rời màn hình.
4. **Cài đặt:** Từ màn hình chính chọn **Cài đặt**. Đổi **Tự động đọc kết quả**, **Rung phản hồi** và tốc độ **Chậm / Vừa / Nhanh**. Quay lại rồi mở lại để kiểm tra giá trị vẫn giữ trong phiên chạy. Giá trị sẽ về mặc định khi đóng ứng dụng.
5. **Hướng dẫn:** Từ màn hình chính chọn **Hướng dẫn** để đọc năm bước sử dụng. **Nghe hướng dẫn** thông báo chức năng âm thanh sẽ được TV3 kết nối. **Về màn hình nhận diện** hoặc nút quay lại đều trở về bình thường.

## Phần UI đã hoàn thành và giới hạn mô phỏng

| Thành phần | Hiện có | Chưa có |
| --- | --- | --- |
| Nhận diện | Khung căn chỉnh, vùng mệnh giá lớn, 5 trạng thái sẵn sàng/đang quét/đã nhận diện/chưa rõ/lỗi, cảnh báo và hướng dẫn điều chỉnh bằng chữ | Camera stream, YOLO/TFLite, logic nhiều frame, đọc kết quả tự động |
| Phiên quét | Bắt đầu/quét lại, xóa kết quả cũ, phản hồi giao diện và thông báo mock | Điều phối phiên thật, chống đọc lặp, phản hồi bằng giọng nói |
| Đọc lại | Chỉ bật khi có kết quả, hiện thông báo mock | TTS thật |
| Quyền camera | Giải thích mục đích, đồng ý/từ chối mô phỏng, lối thoát khi từ chối | Xin quyền Android thật hoặc mở cài đặt hệ thống |
| Cài đặt | Công tắc tự đọc/rung và tốc độ giọng nói, giữ trong bộ nhớ khi chuyển màn | Kết nối TTS/rung, lưu xuống thiết bị |
| Hướng dẫn | Năm bước ngắn, nút nghe và điều hướng | Phát âm thanh hướng dẫn |

Ảnh phác thảo cho thấy mệnh giá ngay khi mở ứng dụng, phiên tự bắt đầu sau 15 giây và cài đặt được lưu tự động. Bản UI này **không hiển thị mệnh giá giả trước khi chọn demo**, **không chạy bộ đếm thời gian** và **không lưu cài đặt sau khi đóng app**; các quy tắc phiên và lưu trữ cần được nhóm thống nhất trước khi tích hợp.

## File thuộc phần việc TV1

- Khởi chạy, theme, chuỗi và hằng số UI: `lib/main.dart`, `lib/app.dart`, `lib/core/constants/`, `lib/core/theme/`.
- Hợp đồng trình bày tạm: `lib/core/models/recognition_ui_state.dart`, `lib/core/models/app_settings.dart`.
- Bốn màn hình: `lib/screens/recognition/`, `lib/screens/permission/`, `lib/screens/settings/`, `lib/screens/guide/`.
- Widget dùng chung: `lib/widgets/accessible_button.dart`, `camera_frame.dart`, `denomination_card.dart`, `recognition_status.dart`.
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

Đã xác nhận trong môi trường phát triển: `flutter pub get`, format `lib`/`test`, `dart analyze lib test` (không có lỗi), `flutter analyze --no-pub`, `flutter test` **9/9 đạt**, và `flutter build apk --debug` cùng `flutter build web --debug` thành công với Flutter 3.47.7 (các lệnh Flutter cần `subst` vì đường dẫn Unicode). Năm test trong `test/recognition_widgets_test.dart` kiểm tra nút Đọc lại, nhãn Semantics của kết quả demo, câu trạng thái cho dữ liệu thật, cảnh báo chưa rõ/lỗi và màn hình 320 × 568 với chữ gấp đôi. Bốn test trong `test/app_navigation_test.dart` kiểm tra điều hướng, quyền mô phỏng, xóa kết quả khi quét lại, giữ cài đặt trong phiên và bố cục màn phụ khi tăng cỡ chữ.

Bản Web đã khởi động trong Chrome và kết nối Flutter debug service. Lần thử `flutter test --platform chrome` bị kẹt ở bước nạp test, nên chưa xem là kiểm thử trình duyệt đạt; 9 widget test thông thường đã đạt.

**Chưa chạy ứng dụng trên thiết bị/emulator Android; chưa kiểm tra TalkBack thực tế trên thiết bị.** Trước khi bàn giao tích hợp, kiểm tra thủ công:

`flutter doctor -v` trên máy hiện tại còn cảnh báo Flutter/Dart chưa nằm trong `PATH` và một số giấy phép Android chưa được chấp nhận. Android SDK đã có và APK debug vẫn build thành công. `adb devices` không thấy điện thoại, danh sách AVD trống; cần kết nối thiết bị hoặc tạo emulator để chạy thử UI trên Android.

- [ ] Mở cả bốn màn hình, quay lại bằng nút trong ứng dụng và nút Back của Android; không crash.
- [ ] Ở màn hình chính, Đọc lại bị vô hiệu hóa khi chưa có kết quả; bật sau “Thử thành công”; Quét lại xóa kết quả ngay.
- [ ] “Thử chưa rõ” và “Thử lỗi” hiển thị cảnh báo bằng chữ và không giữ mệnh giá cũ.
- [ ] Từ chối quyền mô phỏng vẫn quay lại hoặc tiếp tục được; không xuất hiện hộp thoại xin quyền hệ thống.
- [ ] Đổi cả ba cài đặt, rời màn hình rồi quay lại; giá trị giữ trong phiên, không kỳ vọng giữ sau khi đóng app.
- [ ] Bật TalkBack, vuốt theo thứ tự đọc tự nhiên qua tiêu đề, trạng thái, khung, mệnh giá và các nút; nhãn kết quả demo chỉ đọc một lần. Kích hoạt nút theo thao tác TalkBack chuẩn.
- [ ] Tăng cỡ chữ hệ thống đến mức lớn, thử màn hình nhỏ và xoay màn hình; nội dung vẫn cuộn được, nút không bị cắt.
- [ ] Thử Nghe hướng dẫn/Đọc lại và xác nhận thông báo nói rõ chưa phát âm thanh thật.

Các mục kiểm tra trên thiết bị là việc còn lại; APK build thành công không chứng minh hành vi Android/TalkBack thực tế.
