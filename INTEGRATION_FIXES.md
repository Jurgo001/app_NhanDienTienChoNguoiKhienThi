# Kết quả sửa và tích hợp TV1–TV2–TV3

Kiểm tra ngày 16/10/2026 trên Windows, Flutter 3.47.7 / Dart 3.13.5, JDK 23.0.2. Đây là trạng thái **sau khi sửa**; [báo cáo rà soát ban đầu](INTEGRATION_REVIEW.md) được giữ để đối chiếu.

## Kết quả xác nhận

| Kiểm tra | Kết quả |
| --- | --- |
| Unit/widget test | **59/59 đạt** |
| Dart analyzer cho lib và test | **No issues found** |
| Build Web JavaScript | Thành công |
| Chrome headless, bundle cuối | Qua Nhận diện → Tùy chọn → Hướng dẫn → bắt đầu quét → kết quả mô phỏng → Quyền camera; **0 runtime exception** |
| Flutter run Chrome debug | Khởi động và kết nối debug service thành công (23,1 giây); đã đóng phiên headless sau kiểm thử |
| Flutter build APK debug tại project hiện tại | Thành công, dùng cấu hình JDK/Gradle đã sửa |
| APK release | Thành công qua scripts/build_release.ps1; build ở thư mục tạm ASCII, chép APK về project và dọn thư mục tạm |
| Model trong cả hai APK | SHA-256 khớp asset gốc; đủ runtime CPU arm64-v8a, armeabi-v7a và x86_64 |

APK để cài: [app-release.apk](build/app/outputs/flutter-apk/app-release.apk), 72.902.475 byte, khoảng **69,5 MiB**. Khóa ký hiện là khóa debug dùng cho chạy/nộp bài nội bộ.

- Model SHA-256: `e9ba6475885c939b0460a41041a3a6609c5fdcdda2ca847f0b2381ecf6ced3c4`.
- APK release SHA-256: `69b9a0606d55ff4a39c974c9b8630183395849e35c3242ce0a01485fa4e251e6`.

Bằng chứng trong [build/verification](build/verification/): tests.log, analyze.log, web-build-final.log, chrome-smoke.json và ảnh từng màn, android-debug-final.log, android-release-final.log, apk-verification.json. Thư mục build bị Git bỏ qua và có thể mất khi flutter clean.

## Luồng đã nối

- `main.dart` mở MoneyRecognitionApp với bốn màn riêng; màn TV2 chuyển sang `main_detector_test.dart`.
- App tạo một ScanSession, NativeScanBackend, CameraService và MoneyDetector dùng chung. Frame camera đi qua tiền xử lý → TFLite worker → decoder/NMS → RecognitionController.
- Confidence tối thiểu 0.78, cần 3 frame liên tiếp cùng mệnh giá. UI nhận cả số tiền và câu đọc từ Denomination cho đủ 9 mệnh giá.
- Kết quả xác nhận đọc/rung một lần theo cài đặt. Đọc lại dùng kết quả hiện tại. Hướng dẫn chất lượng ảnh được đọc sau khi ổn định, cách nhau ít nhất 8 giây khi bật tự động đọc.
- Quét lại xóa kết quả ngay, đổi token và bỏ callback cũ. Tự tạo phiên mới sau 15 giây; mở màn phụ/xuống nền hủy timer và dừng camera/phản hồi.
- Quyền camera dùng API hệ thống thật, có luồng bị chặn → cài đặt ứng dụng. Nghe hướng dẫn đã dùng TTS; nút Bắt đầu nhận diện đi qua cùng pipeline quét.
- Cài đặt cập nhật ngay và ghi tuần tự; đổi nhanh hai công tắc không còn ghi đè nhau. SharedPreferences lưu cho lần mở app sau.
- TTS thiếu giọng hiển thị hướng dẫn và nút thử lại, không chặn giao diện. Có hủy lời đọc cũ khi đổi phiên.
- Backend Web qua conditional import dùng dữ liệu mô phỏng, có nhãn trên UI và trong lời đọc; không kéo dart:ffi vào trình biên dịch web.
- Camera/model lỗi được chuyển về UI để thử lại. Teardown đợi frame đang chạy trước khi đóng interpreter; detector vẫn được dọn nếu camera stop báo lỗi.

## Sáu lỗi hồi quy đã sửa

| Lỗi | Kiểm chứng |
| --- | --- |
| Không mở lại camera sau inactive/resumed | Test camera platform giả và resume phiên quét |
| Đổi nhanh cài đặt mất một thay đổi | Test ghi đồng thời và đọc lại storage |
| skippedBusy làm mất hai frame hợp lệ | Test hai frame → busy → frame thứ ba |
| noMoney giữ hướng dẫn quá tối | Test guidance được thay bằng noMoney |
| Quét lại vẫn giữ UI cũ khi TTS stop chưa xong | Test stop bằng Completer; state xóa trước await |
| Resize 2×2 làm mất pixel | Test đúng RGB cả 4 pixel, đủ 4 góc xoay, NCHW/NHWC và stride Y/U/V riêng |

Tiền xử lý được hợp nhất trong ImageConverter cho cả worker và test, sửa phép lấy mẫu, độ lệch chuẩn, BGRA brightness và quy đổi box sau letterbox. Decoder kiểm tra độ dài output, số class và loại NaN/Infinity. ModelContract chặn tensor/dtype không được hỗ trợ; thứ tự 18 nhãn được đối chiếu trực tiếp với metadata trong asset bằng test.

## Cấu hình Android đã sửa

- Flutter được cấu hình dùng JDK 23 có sẵn tại `C:\Program Files\Java\jdk-23`. Đây là lựa chọn Flutter lưu cho các project tiếp theo; không thay PATH/Java hệ thống.
- Plugin compatibility đặt Kotlin JVM target của tflite_flutter bằng Java 8 và bổ sung compile dependency concurrent-futures cho CameraX. Không sửa Pub cache.
- Thêm query TTS_SERVICE trong manifest theo [hướng dẫn flutter_tts](https://pub.dev/packages/flutter_tts).
- Loại dependency GPU không dùng vì app chọn Interpreter CPU 4 threads; sửa lỗi lớp GpuDelegateFactory.Options khi R8 chạy. Giữ R8 kiểm tra và thu gọn release.
- android.overridePathCheck cho phép debug tại đường dẫn project có dấu. Release AOT vẫn lỗi khi gen_snapshot đọc app.dill ở đường dẫn này, nên script build release dùng một bản sao source tạm không dấu.
- Script chỉ sao chép source cần thiết, kiểm tra đường dẫn GUID trước khi dọn, không sao chép cache/build/Git và không tạo ổ đĩa ảo. Đã xác nhận thư mục tạm được dọn sau cả build lỗi và build thành công.

Build Web hiện theo JavaScript thông thường. Plugin flutter_tts 4.2.5 còn cảnh báo ở kiểm tra WebAssembly; chưa hỗ trợ cam kết build Wasm. Flutter cũng cảnh báo bộ Gradle/AGP/Kotlin hiện tại sẽ cần nâng khi cập nhật SDK trong tương lai; bộ phiên bản ghi trên đã build được debug/release.

## Phần cần kiểm tra trên thiết bị

Máy kiểm thử hiện chỉ thấy Windows/Chrome/Edge, chưa có điện thoại Android hoặc AVD kết nối. Vì vậy chưa xác nhận camera/TFLite, tốc độ/độ ổn định, giọng/rung và TalkBack **trên thiết bị thật**.

Chrome headless không có giọng vi-VN; đã kiểm tra cảnh báo này không ngăn mở/điều hướng/quét mô phỏng. Lời gọi TTS/haptic và hủy lời đọc được xác nhận qua service giả/method channel test; cần nghe/rung thật trên điện thoại để nghiệm thu.

Model nạp/suy luận CPU máy tính với ba ảnh tổng hợp đã đạt trong đợt rà soát trước; tensor và metadata đã được kiểm tra lại trong bộ test. Project chưa có bộ ảnh validation chưa dùng khi train nên **chưa thể đo độ chính xác nhận diện tiền thật**. Tiền xử lý hiện dùng letterbox/RGB/255; cần đối chiếu ảnh validation và pipeline train để hiệu chỉnh nếu cần.

Kiểm tra trên Android: cấp/từ chối/cấp lại quyền; đủ 9 mệnh giá và hai mặt; không tiền/nhiều tờ/thiếu sáng/quá gần/xa; Đọc lại/Quét lại/15 giây; đổi nhanh cài đặt rồi khởi động lại; chuyển nền và quay lại; mở Hướng dẫn/Tùy chọn trong lúc quét; thao tác TalkBack và nghe/rung thực tế.

Lệnh chạy Chrome, Android và build APK ở [README.md](README.md).