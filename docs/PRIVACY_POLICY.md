# Chính sách quyền riêng tư — Sổ Thu Chi

**Ngày hiệu lực:** 02/08/2026
**Nhà phát triển:** itquanghuy85@gmail.com
**Ứng dụng:** Sổ Thu Chi (package `com.moneyflow.mobile`)

Sổ Thu Chi là ứng dụng quản lý dòng tiền cho chủ shop nhỏ và gia đình. Tài liệu
này mô tả chính xác những dữ liệu ứng dụng thu thập, vì sao, và cách bạn kiểm
soát nó — dựa trên đúng những gì ứng dụng hiện đang làm, không phải một mẫu
chính sách chung chung.

## 1. Dữ liệu chúng tôi thu thập

| Loại dữ liệu | Cụ thể | Bắt buộc? |
|---|---|---|
| Tài khoản | Email, họ tên; số điện thoại (tùy chọn khi đăng ký) | Có (email/họ tên) |
| Đăng nhập mạng xã hội | Nếu chọn Google/Apple: email, họ tên cơ bản do Firebase Authentication cung cấp | Tùy chọn |
| Dữ liệu tài chính do bạn nhập | Giao dịch thu/chi/chuyển tiền, số dư túi tiền, ngân sách, giao dịch định kỳ, ca làm việc, chốt sổ | Có (đây là chức năng cốt lõi) |
| Dữ liệu khách hàng/công nợ | Tên, số điện thoại khách hàng bạn tự nhập để theo dõi công nợ | Tùy chọn |
| Token thiết bị | Firebase Cloud Messaging token, để gửi thông báo đẩy | Tự động khi đăng nhập |
| Nhật ký thao tác | Ai sửa/hủy giao dịch nào, khi nào (phục vụ tính minh bạch nội bộ workspace) | Tự động |

**Chúng tôi KHÔNG thu thập:** vị trí GPS, danh bạ máy, ảnh/camera, lịch sử
duyệt web, hay bất kỳ dữ liệu nào để quảng cáo/theo dõi liên ứng dụng. Ứng
dụng không tích hợp SDK quảng cáo hay phân tích hành vi (analytics) của bên
thứ ba.

## 2. Quyền truy cập thiết bị và cách dùng

| Quyền | Dùng để làm gì | Dữ liệu có rời khỏi máy không? |
|---|---|---|
| Micro (`RECORD_AUDIO`) | Tính năng nhập giao dịch bằng giọng nói | **Không** — nhận dạng giọng nói chạy bằng công cụ có sẵn của hệ điều hành (on-device), bản ghi âm không được gửi lên máy chủ của chúng tôi |
| Vân tay / Face ID (`USE_BIOMETRIC`) | Khóa ứng dụng bằng sinh trắc học thay vì gõ mã PIN | **Không** — xử lý hoàn toàn bởi hệ điều hành; chúng tôi không nhận hay lưu dữ liệu sinh trắc học |
| Thông báo (`POST_NOTIFICATIONS`) | Báo giao dịch mới, ngân sách vượt hạn mức, nhắc lịch | Token thiết bị được gửi tới Firebase Cloud Messaging (Google) để định tuyến thông báo |
| Mạng (`INTERNET`) | Đồng bộ dữ liệu với máy chủ | Có — đây là cách ứng dụng hoạt động |

Mã PIN mở khóa ứng dụng được lưu **cục bộ trên máy** (Android Keystore / iOS
Keychain qua `flutter_secure_storage`) — không gửi lên máy chủ.

## 3. Nơi lưu trữ và cách bảo vệ dữ liệu

- Dữ liệu được lưu trong cơ sở dữ liệu PostgreSQL do **Neon** quản lý, thông
  qua máy chủ backend chạy trên **Render**.
- Mọi kết nối giữa ứng dụng và máy chủ đều qua **HTTPS** (mã hóa khi truyền).
- Mật khẩu được băm (hash) bằng bcrypt, không bao giờ lưu dạng thô.
- Truy cập API yêu cầu token JWT (tự hết hạn, làm mới định kỳ).

## 4. Chia sẻ dữ liệu với bên thứ ba

Chúng tôi **không bán** và **không chia sẻ dữ liệu cho mục đích quảng cáo**.
Dữ liệu chỉ đi qua các nhà cung cấp hạ tầng cần thiết để vận hành ứng dụng:

- **Google Firebase** — xác thực đăng nhập (Google/Apple sign-in) và gửi
  thông báo đẩy (Firebase Cloud Messaging).
- **Neon** — lưu trữ cơ sở dữ liệu.
- **Render** — chạy máy chủ backend.

Mỗi bên chỉ nhận dữ liệu cần thiết cho đúng chức năng của họ, theo chính sách
bảo mật riêng của từng nhà cung cấp.

## 5. Dữ liệu trong cùng một workspace

Sổ Thu Chi hoạt động theo mô hình không gian làm việc (workspace) dùng
chung: chủ shop mời nhân viên/thành viên gia đình cùng xem hoặc nhập giao
dịch. Trong cùng một workspace, các thành viên có thể thấy giao dịch, số dư,
và tên người tạo giao dịch của nhau — đây là mục đích cốt lõi của ứng dụng
(sổ sách minh bạch, không phải rò rỉ dữ liệu). Chủ workspace (Owner) toàn
quyền mời/xóa thành viên.

## 6. Quyền của bạn

- **Xem/sửa dữ liệu**: trực tiếp trong ứng dụng (sửa hồ sơ, sửa/hủy giao
  dịch — mọi thay đổi đều lưu vết trong Lịch sử chỉnh sửa).
- **Yêu cầu xóa tài khoản/dữ liệu**: hiện tại ứng dụng **chưa có nút tự xóa
  tài khoản trong app**. Vui lòng gửi yêu cầu tới
  **itquanghuy85@gmail.com** kèm email đã đăng ký — chúng tôi sẽ xóa toàn
  bộ dữ liệu liên quan trong vòng 30 ngày.
  > *Ghi chú cho nhà phát triển: đây là điểm cần bổ sung một nút "Xóa tài
  > khoản" thực sự trong app trước khi nộp App Store/Play Store — xem
  > `docs/SUBMISSION_CHECKLIST.md`.*

## 7. Trẻ em

Ứng dụng không hướng đến và không cố ý thu thập dữ liệu từ trẻ em dưới 13
tuổi.

## 8. Thay đổi chính sách

Nếu chính sách này thay đổi, ngày hiệu lực ở đầu trang sẽ được cập nhật.
Thay đổi quan trọng sẽ được thông báo trong ứng dụng.

## 9. Liên hệ

Mọi câu hỏi về quyền riêng tư, gửi email tới **itquanghuy85@gmail.com**.
