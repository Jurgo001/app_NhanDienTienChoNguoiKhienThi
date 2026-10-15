# TÀI LIỆU GHI CHÚ BÀN GIAO MODULE TV2 (CAMERA & AI INTEGRATION)

Tài liệu này liệt kê chi tiết các file đã triển khai theo phân công, các class/thuộc tính phụ trợ được thiết kế thêm để hệ thống hoạt động ổn định, cùng hướng dẫn kết nối dành cho **TV3 (Logic & Accessibility)**.

---

## 1. Danh sách các thành phần đã tạo mới / bổ sung thêm ngoài tên file khung

Để giải quyết triệt để lỗi crash TFLite, lỗi tràn RAM khi stream camera và cung cấp dữ liệu đầy đủ cho TV3, các thành phần phụ trợ sau đã được bổ sung:

1. **`enum BanknoteSide` (`lib/models/denomination.dart`)**:
   - **Mục đích**: Phân biệt tờ tiền đang ngửa mặt trước (`front`), mặt sau (`back`), hay chưa rõ (`unknown`) dựa trên hậu tố `_mattruoc` / `_matsau` của model.
2. **`enum DetectionStatus` (`lib/models/detection_result.dart`)**:
   - **Mục đích**: Cung cấp 10 mã trạng thái chuẩn hóa sau mỗi khung hình:
     - `detected`: Nhận diện thành công 1 tờ tiền vượt ngưỡng tin cậy (`>= 0.78`).
     - `noMoney`: Không có tiền trong khung hình.
     - `lowConfidence`: Có tiền nhưng bị mờ/rung tay (`0.40 <= conf < 0.78`).
     - `multipleNotes`: Phát hiện từ 2 tờ tiền trở lên trong cùng khung hình.
     - `tooClose` / `tooFar`: Tờ tiền chiếm diện tích quá lớn (`> 88%`) hoặc quá nhỏ (`< 8%`).
     - `tooDark` / `tooBright`: Độ sáng trung bình của ảnh quá tối (`< 35`) hoặc cháy sáng (`> 240`).
     - `skippedBusy`: Khung hình được bỏ qua chủ động do luồng AI đang bận xử lý frame trước.
     - `modelError`: Lỗi khi nạp hoặc thực thi TFLite.
3. **`class BoundingBox` (`lib/models/detection_result.dart`)**:
   - **Mục đích**: Lưu tọa độ chuẩn hóa `[0.0 - 1.0]` (`x1, y1, x2, y2`), `classId`, `rawLabel`, `confidence`, `denomination`, `side` và thuộc tính tính sẵn `areaRatio` (tỷ lệ diện tích box).
4. **`class PreprocessedFrame` (`lib/utils/image_converter.dart`)**:
   - **Mục đích**: Đóng gói mảng `Float32List inputBuffer` kèm độ sáng trung bình `meanBrightness` và độ lệch chuẩn `contrastStdDev` chỉ trong 1 vòng lặp duy nhất để tiết kiệm CPU.
5. **`class MappedClassInfo` (`lib/utils/denomination_mapper.dart`)**:
   - **Mục đích**: Kết quả ánh xạ từ 18 nhãn trong `data.yaml` sang cặp `(Denomination, BanknoteSide)`.
6. **`enum MockScenario` (`lib/services/mock_money_detector.dart`)**:
   - **Mục đích**: Cho phép TV3 giả lập 6 tình huống kiểm thử (xoay vòng 9 mệnh giá, cố định 50k, mờ tay, nhiều tờ, quá tối, không có tiền) mà không cần bật camera thật.

---

## 2. Thông số kỹ thuật của Model AI (`best_float32.tflite`)

- **Kiến trúc gốc**: YOLOv8 Nano (`yolov8n.pt` -> `best.pt` -> `best_float32.tflite`).
- **Đường dẫn Asset**: `assets/models/best_float32.tflite`
- **Kích thước đầu vào (Input Shape)**: `416 x 416` (Hỗ trợ tự động cả `NCHW [1, 3, 416, 416]` và `NHWC [1, 416, 416, 3]`).
- **Kích thước đầu ra (Output Shape)**: `[1, 22, 3549]` (4 tọa độ box + 18 classes = 22 kênh; 3549 neo dự đoán).
- **Danh sách 18 Class theo thứ tự Index `0 -> 17`**:
  - `0`: `10000_matsau` | `1`: `10000_mattruoc`
  - `2`: `1000_matsau` | `3`: `1000_mattruoc`
  - `4`: `100k_matsau` | `5`: `100k_mattruoc`
  - `6`: `20000_matsau` | `7`: `20000_mattruoc`
  - `8`: `2000_matsau` | `9`: `2000_mattruoc`
  - `10`: `200k_matsau` | `11`: `200k_mattruoc`
  - `12`: `50000_matsau`| `13`: `50000_mattruoc`
  - `14`: `5000_matsau` | `15`: `5000_mattruoc`
  - `16`: `500k_matsau` | `17`: `500k_mattruoc`

---

## 3. Hướng dẫn cho TV3 tích hợp vào `RecognitionController`

TV3 chỉ cần phụ thuộc vào `DetectorService` và `CameraService`:

```dart
final DetectorService detector = MoneyDetector(); // Hoặc MockMoneyDetector() khi test
final CameraService cameraService = CameraService(minFrameIntervalMs: 120);

await detector.initialize();
await cameraService.initializeCamera();

await cameraService.startStream((cameraImage, sensorOrientation) async {
  final DetectionResult result = await detector.detectFrame(
    cameraImage,
    sensorOrientation: sensorOrientation,
  );

  if (result.status == DetectionStatus.skippedBusy) return;

  if (result.isRecognized) {
    // Đưa result.denomination vào bộ đếm ổn định nhiều frame (ví dụ: 3 frames liên tiếp trùng nhau)
    // Sau đó phát TTS: result.denomination!.spokenText
  } else {
    // Xử lý hướng dẫn giọng nói khi quá tối / quá xa / mờ tay qua result.message
  }
});
```
