> **Báo cáo trước khi sửa.** Các lỗi và phần chưa nối dưới đây là hiện trạng lúc rà soát ban đầu. Bản sửa tích hợp đã được triển khai; xem [INTEGRATION_FIXES.md](INTEGRATION_FIXES.md) và [README.md](README.md) để biết kết quả kiểm thử và lệnh chạy hiện tại.

# Rà soát tích hợp TV1–TV2–TV3

Ngày kiểm tra: **16/10/2026**. Mã nguồn lúc bắt đầu: `1d2c9c7abc63b2dd6bc8eab6e0944e7ad2df82d5`. Flutter 3.47.7, Dart 3.13.5, Windows.

## 1. Kết luận

Project **chưa có luồng ứng dụng hoàn chỉnh**. Các module camera/TFLite, TTS, rung và lưu cài đặt có triển khai thật; vấn đề chính là điểm khởi động và các đoạn nối giữa module.

Luồng đang có:

- `lib/main.dart` → `DetectorTestScreen` → `CameraService` → `MoneyDetector` → bảng debug. Không gọi `RecognitionController.processDetection()`, không nối sang giao diện bốn màn, TTS hoặc rung.
- `MoneyRecognitionApp` trong `lib/app.dart` → giao diện TV1 → `RecognitionController`/các service TV3. Kết quả nhận diện được tạo qua nút demo; không có CameraService/MoneyDetector trong luồng này.
- Khi test có fake plugin đúng cách, luồng TV1 → nút demo → controller TV3 → lời gọi TTS hoạt động. Đây là kiểm thử lời gọi với plugin giả, không phải xác nhận đã phát âm thanh trên điện thoại.

Luồng cần hoàn thiện:

```text
Khởi động app → tải cài đặt → kiểm tra TTS/model
→ xin quyền camera thật → mở preview
→ Bắt đầu quét → CameraImage → tiền xử lý → TFLite → YOLO/NMS
→ DetectionResult → xác nhận 3 frame ổn định
→ cập nhật UI + đọc tiếng Việt/rung theo cài đặt
→ Đọc lại hoặc Quét lại
```

## 2. Kết quả đã chạy

| Kiểm tra | Kết quả thực tế |
| --- | --- |
| Lấy dependencies | Thành công. Pub resolver điều chỉnh 5 dependency gián tiếp cho SDK hiện tại. |
| Phân tích code trên bản sao đường dẫn ASCII | Không có compile error Dart; **1 warning, 2 info**: unused import ở MoneyDetector, unnecessary import ở CameraService, activeColor deprecated ở màn debug. |
| Test có sẵn | **21 đạt, 7 lỗi / 28 test**. Bảy test điều hướng khởi tạo MoneyRecognitionApp chưa thiết lập SharedPreferencesAsyncPlatform. |
| Test chẩn đoán riêng | **7 đạt, 6 lỗi / 13 test**. Sáu lỗi logic được mô tả ở mục 4. |
| Model TFLite trên CPU máy tính | Nạp, cấp phát tensor và suy luận thành công với ảnh đen/xám/trắng; output hữu hạn, không có detection vượt 0.78 trên ba ảnh tổng hợp này. |
| Build Chrome bằng main.dart hiện tại | **Lỗi:** `dart:ffi` không dùng được trên Web, bị kéo vào qua tflite_flutter. |
| Build APK với cấu hình hiện tại | **Lỗi:** Flutter chọn JDK 25.0.3, không tương thích Gradle 8.14. |
| Build bản sao bằng JDK 23 | Vượt lỗi Java nhưng lỗi JVM target của tflite_flutter: Java 1.8 / Kotlin 23. |
| Thêm JVM override tạm | Tiếp tục phát hiện lỗi CameraX thiếu `androidx.concurrent.futures.CallbackToFutureAdapter` khi compile Java. |
| Bản sao dùng JDK 23 + JVM override + dependency CameraX tạm | **BUILD SUCCESSFUL** (1 phút 52 giây). Chỉ bản sao có cấu hình tương thích tạm build thành công; chưa sửa cấu hình project gốc. |
| Thiết bị Android/TalkBack | Không có Android device kết nối, không có AVD sẵn. Chưa kiểm tra camera/âm thanh/rung thực tế. |

Chạy `flutter analyze` ngay tại đường dẫn có dấu ban đầu làm công cụ LSP lỗi `FormatException: Unexpected end of input`. Vì vậy phân tích và build được thực hiện trên **bản sao cùng source ở đường dẫn ASCII**, không tạo ổ ảo hoặc di chuyển project gốc.

Log, mã test chẩn đoán và APK debug của **màn TV2 hiện tại** ở [build/review](build/review/). Model trong APK đã được đối chiếu SHA-256 với asset gốc. Đây chưa phải APK ứng dụng tích hợp.

Đã giữ bản dependency resolved dùng khi kiểm thử ở `build/review/pubspec.resolved.lock` và khôi phục `pubspec.lock` ban đầu; không sửa code ứng dụng trong đợt rà soát này.

Log và mã test chẩn đoán ở [build/review](build/review/). Đây là thư mục build bị Git bỏ qua, có thể bị xóa khi chạy `flutter clean`.

## 3. Model mới train

File: [assets/models/best_float32.tflite](assets/models/best_float32.tflite)

| Thuộc tính | Đọc trực tiếp từ file |
| --- | --- |
| Dung lượng | 12.722.294 byte |
| SHA-256 | `e9ba6475885c939b0460a41041a3a6609c5fdcdda2ca847f0b2381ecf6ced3c4` |
| Input | float32 `[1, 3, 416, 416]` — NCHW |
| Output | float32 `[1, 22, 3549]` |
| Class | 18 lớp, gồm 9 mệnh giá × mặt trước/sau |
| Metadata | Có `metadata.json`, task `detect`, image size 416 × 416 |
| Mapping | Cả 18 nhãn và thứ tự **khớp** `DenominationMapper.classLabels` |
| Decoder | Test đầu ra tổng hợp cho đủ 18 lớp và hai layout được code hỗ trợ đều đạt |

Thông số hiện tại phù hợp với nhánh float32/NCHW của MoneyDetector. Chưa có bằng chứng file model bị hỏng hoặc sai thứ tự nhãn.

**Chưa thể kết luận độ chính xác trên tiền thật:** trong project không có bộ ảnh test có nhãn, data.yaml hoặc báo cáo validation để đo. Suy luận trên máy tính không xác nhận tốc độ, bộ nhớ hoặc khả năng chạy của runtime TFLite trên điện thoại. Chi tiết ở [model_inspection.json](build/review/model_inspection.json).

Cần bổ sung bộ ảnh chưa dùng khi train, đủ 9 mệnh giá/hai mặt, ảnh không có tiền và nhiều tờ. Đo cả tỷ lệ đọc sai mệnh giá, không chỉ kiểm tra model có trả output.

## 4. Các điểm cần sửa và kết nối, theo thứ tự

### P0 — Ghép luồng chính và làm build chạy được

| File | Hiện trạng | Việc cần làm |
| --- | --- | --- |
| `lib/main.dart:11` | Mở thẳng DetectorTestScreen. | Đưa MoneyRecognitionApp về entrypoint chính; tách màn TV2 thành `lib/main_detector_test.dart` để test độc lập. |
| `lib/app.dart`, `lib/controllers/recognition_controller.dart` | Không tạo/nối CameraService và DetectorService. | Tiêm service qua constructor; initialize model/camera; mỗi frame gọi detectFrame rồi đưa DetectionResult vào processDetection. Có session ID để bỏ kết quả cũ sau Quét lại. |
| `lib/app.dart`, `lib/screens/recognition/recognition_screen.dart` | Không truyền cameraPreview cho màn nhận diện. | Truyền CameraPreview của controller đã sẵn sàng; thông báo đúng trạng thái chờ/quyền/lỗi. |
| `lib/app.dart:144,169` | Bắt đầu/Quét lại bị chặn ở release bằng kDebugMode. | Luồng thật phải chạy ở debug và release; chỉ các công cụ giả lập mới giới hạn debug. |
| `lib/services/money_detector.dart`, các entrypoint/factory | Import tflite_flutter trực tiếp làm Chrome không compile. | Dùng conditional import/export cho backend native và web. Chỉ if(kIsWeb) trong hàm không giải quyết import dart:ffi. Chrome có thể dùng UI/mock; nếu cần nhận diện thật trên web phải có runtime/backend web riêng. |
| `android/build.gradle.kts`, cấu hình JDK | JDK 25 / Gradle 8.14 không tương thích; module TFLite lệch JVM target. | Chọn JDK tương thích. Đã thử JDK 23 có sẵn; nếu cài mới có thể chọn JDK 17/21. Đồng bộ Java/Kotlin trong từng module, xử lý riêng target của tflite_flutter, không tắt validation để che lỗi. |
| `android/build.gradle.kts` hoặc bộ phiên bản dependency trong `pubspec.yaml`/`pubspec.lock` | CameraX compile thiếu CallbackToFutureAdapter trong cấu hình đã thử. | Xác nhận compile dependency concurrent-futures; bản thử dùng `androidx.concurrent:concurrent-futures:1.1.0`. Hoặc chọn bộ phiên bản plugin tương thích và build lại. Không sửa trực tiếp Pub cache. |

Cấu hình build thử được lưu tại [review-build-override.gradle](build/review/review-build-override.gradle). Đây là chứng cứ/workaround kiểm thử, chưa được áp dụng vào Gradle của project gốc.

### P1 — Sáu lỗi đã tái hiện bằng test

| Lỗi | File/vị trí | Hướng sửa |
| --- | --- | --- |
| Camera không mở lại sau inactive → resumed | `lib/services/camera_service.dart:133` | Nhánh inactive đã đặt controller=null, nhưng đầu hàm return khi null nên resumed không thể initialize. Xử lý resumed trước guard, quản lý trạng thái camera và stream cần phục hồi. |
| Đổi nhanh hai cài đặt bị mất một thay đổi | `lib/controllers/settings_controller.dart:49` | State chỉ cập nhật sau await save; hai thao tác cùng tạo bản sao từ state cũ. Cập nhật state nhất quán và tuần tự hóa ghi storage, xử lý lỗi lưu. |
| skippedBusy xóa bộ đếm hai frame hợp lệ | `lib/controllers/recognition_controller.dart:74` | Bỏ qua skippedBusy trước khi xóa candidate/consecutiveFrames; đó không phải một frame nhận diện sai. |
| noMoney giữ hướng dẫn tooDark cũ | `lib/controllers/recognition_controller.dart:78` | Khi không còn tiền, thay hướng dẫn bằng thông điệp noMoney, đồng thời reset bộ đếm phù hợp. |
| Quét lại vẫn hiện kết quả cũ lúc chờ TTS stop | `lib/controllers/recognition_controller.dart:159` | Xóa state UI/đổi session ngay, sau đó await stop; ngăn kết quả in-flight của phiên cũ chen vào phiên mới. |
| Resize cùng kích thước không giữ nguyên các pixel khác nhau | `lib/utils/image_converter.dart:139`, công thức lặp lại ở `lib/services/money_detector.dart:285` | Sửa phép lấy mẫu pixel; test 2×2 hiện trả bốn pixel đỏ thay vì đỏ/xanh lá/xanh dương/trắng. Hợp nhất hai pipeline tiền xử lý, kiểm tra stride, góc xoay và stretch/letterbox theo pipeline train. |

Test chẩn đoán: [integration_audit_test.dart](build/review/integration_audit_test.dart). Các test có tên BUG đặt kỳ vọng hành vi cần có và đang thất bại; không phải lỗi do đã sửa code.

Ngoài sáu lỗi trên, cần khóa an toàn tài nguyên: `MoneyDetector.dispose()` đóng interpreter ngay trong khi worker isolate có thể đang invoke. Thứ tự kết thúc phải là ngừng nhận frame → đợi inference đang chạy → đóng interpreter/camera. Đây là rủi ro từ đọc code, chưa tái hiện crash trên thiết bị.

### P1 — Quyền thật, hướng dẫn âm thanh và trạng thái sử dụng

- `lib/app.dart:284` và `lib/screens/permission/camera_permission_screen.dart`: các nút chỉ đổi MockPermissionDecision. Nối requestCameraPermission và xử lý denied/permanentlyDenied; hộp thoại chọn quyền thực tế do Android hiển thị. Khi cần, đưa người dùng đến cài đặt ứng dụng.
- `lib/app.dart:262`: Nghe hướng dẫn vẫn chỉ hiện SnackBar. Nối SpeechService.speak với nội dung ba bước. Nút Bắt đầu nhận diện từ Hướng dẫn hiện chỉ pop route; cần đi qua cùng hành động bắt đầu quét thật.
- `lib/services/speech_service.dart`: kiểm tra có engine/giọng vi-VN, xử lý kết quả thiết lập ngôn ngữ, lỗi hoặc hủy TTS. Tránh để lỗi TTS chặn toàn bộ giao diện khởi động mà không có cách thử lại.
- `android/app/src/main/AndroidManifest.xml`: đã có CAMERA và VIBRATE; thiếu khai báo query cho TTS trên Android 11+. Thêm phần sau trực tiếp dưới manifest, ngoài application:

```xml
<queries>
    <intent>
        <action android:name="android.intent.action.TTS_SERVICE" />
    </intent>
</queries>
```

- `RecognitionController`: hiện chỉ đọc mệnh giá khi xác nhận/Đọc lại. Cần nối hướng dẫn tooDark/tooFar/multipleNotes/lowConfidence với TTS có giới hạn tần suất, tránh đọc liên tục mỗi frame.
- Khi mở Hướng dẫn/Tùy chọn, xuống nền hoặc đóng app: thống nhất có tạm dừng quét/TTS hay không; không để lời đọc kết quả cắt lời hướng dẫn. Đồng bộ cờ isMock với backend thật.
- Nếu vẫn yêu cầu tự bắt đầu phiên mới sau 15 giây như ảnh thiết kế, thêm timer ở controller, hủy đúng khi chuyển màn/đóng app và có test; hiện chưa có luồng này.

### P2 — UI, test và tài liệu

- `lib/widgets/denomination_card.dart:55`: phần chữ đọc thành tiền đang hard-code cho chuỗi demo `100.000 đồng`, trong khi DTO mới dùng `100.000 VNĐ`. Dùng displayText/spokenText từ Denomination cho cả 9 mệnh giá.
- `lib/core/constants/app_strings.dart`, `lib/screens/settings/settings_screen.dart:93`, `README.md`: cập nhật thông báo đang nói “chưa có TTS/rung” hoặc chỉ lưu trong phiên. Service mới đã có TTS/rung/persistence, nhưng phải phân biệt chúng với phần nhận diện đang demo.
- `test/app_navigation_test.dart`, `test/mobile_flow_test.dart`: fake SharedPreferencesAsyncPlatform, fake TTS/haptic và chờ initialize. Đồng thời cập nhật thao tác Start trước Demo, định dạng VNĐ và xác nhận TTS thay cho SnackBar mô phỏng cũ.
- Thêm test hồi quy cho sáu lỗi ở trên, model contract/decoder/NMS/tiền xử lý và lỗi quyền/model. Dùng integration_test trên Android cho toàn bộ pipeline.

## 5. Phân chia việc và file nên thêm

| Thành viên | Phần việc tiếp theo |
| --- | --- |
| TV1 | Main/app, cameraPreview, màn quyền thật, hướng dẫn/quay lại, state và thông báo đúng với backend, hiển thị đủ mệnh giá. |
| TV2 | Camera lifecycle/stream, tiền xử lý duy nhất, decoder/NMS, init/dispose model và kiểm thử model bằng ảnh thật. |
| TV3 | Controller điều phối camera–detector–UI, quản lý phiên/3 frame, TTS/rung/hướng dẫn, ghi settings tuần tự và khôi phục sau restart. |
| Cả nhóm | Thống nhất hợp đồng DetectionResult, ngưỡng confidence và yêu cầu phiên quét; sửa build Android và test trên thiết bị. |

Các file mới **đề xuất**, chưa tạo trong mã nguồn ứng dụng:

- `lib/main_detector_test.dart`: entrypoint test TV2 tách khỏi app chính.
- `lib/services/detector_factory.dart`, `detector_factory_native.dart`, `detector_factory_web.dart`: chọn backend bằng conditional import/export nếu giữ hỗ trợ Chrome.
- `test/services/camera_service_test.dart`, `test/controllers/settings_controller_test.dart`, `test/utils/image_converter_test.dart`, `test/utils/yolo_decoder_test.dart`: kiểm thử hồi quy.
- `integration_test/app_test.dart`: kiểm thử trên thiết bị; khi dùng, thêm `integration_test: {sdk: flutter}` vào dev_dependencies.

**Không cần cài thêm package Dart để có luồng Android cơ bản:** pubspec đã có camera, tflite_flutter, image, permission_handler, flutter_tts, shared_preferences và vibration. Cần sửa cách ghép và tương thích build, không chỉ thêm dependency.

File model đã được khai báo trong assets. Không cần best.pt/ONNX để app nạp TFLite; nên giữ data.yaml, bộ ảnh validation và báo cáo train ở nơi bàn giao để kiểm chứng model. Nhãn hiện có sẵn trong metadata, có thể đọc/đối chiếu tự động thay vì nhập tay lần sau.

## 6. Chuẩn bị máy và cách chạy

Trên máy hiện tại:

- Flutter SDK: `D:\sdk_flutter\flutter`.
- Android SDK: `C:\Users\Hao\AppData\Local\Android\sdk`; có platform 36 và NDK. Build kiểm thử đã tải thêm platform 31 mà plugin TFLite yêu cầu.
- JDK mặc định Android Studio: 25.0.3, không chạy được Gradle 8.14. Có JDK 23 tại `C:\Program Files\Java\jdk-23`; các build chẩn đoán dùng JDK này riêng trong tiến trình.
- Một số Android SDK licenses chưa được chấp nhận. Chưa có điện thoại hoặc AVD để chạy thử.
- Cần giọng tiếng Việt trên điện thoại và kiểm tra thiết bị có hỗ trợ rung.

Các lệnh sau dùng để chuẩn bị/chạy thử, **sau khi xử lý các lỗi build ở mục 4**. SDK đã nằm ở đường dẫn không dấu. Nếu Android/analysis tool báo lỗi Unicode ở đường dẫn project, chuyển project bằng File Explorer sang đường dẫn không dấu như `D:\projects\app_HoTroNguoiKhienThi`, mở lại project và đổi Set-Location tương ứng; không cần tạo ổ đĩa ảo.

```powershell
Set-Location "D:\nam4 kì1\app_HoTroNguoiKhienThi"
$flutter = "D:\sdk_flutter\flutter\bin\flutter.bat"

& $flutter doctor -v
& $flutter pub get
& $flutter doctor --android-licenses
& $flutter devices
```

Lệnh licenses mở phần xem/chấp nhận giấy phép; đọc nội dung và xác nhận trực tiếp khi đồng ý.

Nếu chọn dùng JDK 23 đang có, cấu hình Flutter trỏ đến nó rồi kiểm tra lại (đây là thay đổi cấu hình cho những lần chạy sau, chưa được tự áp dụng trong đợt review):

```powershell
& $flutter config --jdk-dir="C:\Program Files\Java\jdk-23"
& $flutter doctor -v
```

Vẫn cần sửa lệch JVM target/dependency CameraX như mục 4; chỉ đổi JDK chưa đủ.

Điện thoại Android: bật Developer options → USB debugging, cắm cáp truyền dữ liệu và chấp nhận hộp thoại cho phép gỡ lỗi. Hoặc tạo/chạy AVD trong Android Studio → Device Manager. Chọn đúng ID từ devices:

```powershell
$deviceId = "ID_ANDROID_TU_DEVICES"
& $flutter run -d $deviceId -t lib/main.dart
```

**Với main.dart hiện tại, lệnh trên mở màn test TV2.** Sau khi sửa entrypoint/pipeline, cùng lệnh mới mở app tích hợp.

Các entrypoint TV3 hiện có để thử riêng trên Android:

```powershell
& $flutter run -d $deviceId -t lib/main_tts_test.dart
& $flutter run -d $deviceId -t lib/main_haptic_test.dart
& $flutter run -d $deviceId -t lib/main_settings_test.dart
```

Chạy từng lệnh riêng, nhấn `q` để dừng phiên trước khi chuyển sang lệnh tiếp theo. Có thể dùng Ctrl+C để ngắt lệnh bị kẹt.

Chrome: `& $flutter run -d chrome` **đang lỗi với main.dart hiện tại**. Cần tách native backend khỏi Web trước; khi đó dùng Chrome để thử UI/mock. Chưa có backend nhận diện TFLite thực sự trên Web trong project.

## 7. Điều kiện nghiệm thu app tích hợp

- App mở bốn màn UI chính; xin quyền camera hệ thống thật, xử lý từ chối và cấp lại.
- Camera preview hoạt động; đưa tiền thật vào nhận diện đúng model, không cần bấm nút demo.
- Chỉ xác nhận sau các frame hợp lệ ổn định; đọc/rung một lần theo cài đặt; Đọc lại đọc đúng mệnh giá hiện tại.
- Quét lại xóa ngay kết quả cũ và không nhận kết quả muộn của phiên trước.
- Các tình huống thiếu sáng, quá gần/xa, nhiều tờ, không có tiền có hướng dẫn phù hợp, không đọc mệnh giá sai do giữ dữ liệu cũ.
- Cài đặt còn đúng sau đóng/mở ứng dụng; thay đổi nhanh không mất dữ liệu.
- Chuyển nền → mở lại, tắt/bật màn hình và mở Hướng dẫn/Tùy chọn không làm hỏng camera hoặc rò tài nguyên.
- Kiểm tra TalkBack trên máy thật: tìm vùng chạm, thứ tự đọc, nhãn/trạng thái và thao tác kích hoạt.
- Test lại bộ ảnh chưa train, ghi nhận nhầm mệnh giá, tỷ lệ không nhận được và độ trễ trên điện thoại.
- Build debug/release và smoke-test trên thiết bị; không dùng việc build được APK để kết luận đã hoàn thiện pipeline.

## Tài liệu đối chiếu

- [tflite_flutter 0.11.0](https://pub.dev/packages/tflite_flutter/versions/0.11.0): nền tảng và thư viện native.
- [Camera lifecycle](https://pub.dev/packages/camera): ứng dụng chịu trách nhiệm quản lý lifecycle camera.
- [flutter_tts 4.2.5](https://pub.dev/packages/flutter_tts/versions/4.2.5): cấu hình TTS và manifest queries.
- [Gradle 8.14 compatibility](https://docs.gradle.org/8.14/userguide/compatibility.html): chọn Java runtime tương thích.
- [Ultralytics export metadata](https://docs.ultralytics.com/reference/engine/exporter): đối chiếu metadata/nhãn nhúng trong model.
