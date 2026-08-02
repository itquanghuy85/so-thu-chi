# Checklist nộp app — Sổ Thu Chi

Thứ tự thực hiện thực tế. Dùng cùng với `docs/STORE_LISTING.md` và
`docs/PRIVACY_POLICY.md`.

## 0. ✅ Đã xong (không cần làm lại)

- [x] **Nút "Xóa tài khoản" trong app** — Cài đặt → Bảo mật → Xoá tài
  khoản. Gọi `DELETE /auth/account`, chặn lại (báo lỗi rõ ràng) nếu bạn
  đang là chủ sở hữu một workspace có thành viên khác, để tránh xoá nhầm
  dữ liệu người khác.
- [x] **Chính sách quyền riêng tư** đã public tại
  **https://sothuchi-d055a.web.app** (Firebase Hosting, dự án
  `sothuchi-d055a`) — dùng thẳng link này làm Privacy Policy URL, không
  cần bước nào thêm.
- [x] **Keystore release đã tạo** tại `mobile/android/app/release.jks`,
  alias `sothuchi`, đã cấu hình ký trong `android/app/build.gradle.kts`
  qua `mobile/android/key.properties` (git-ignored). Build thử
  `flutter build appbundle --release` đã chạy thành công, xác nhận file
  `.aab` được ký đúng bằng key này (không phải debug key).
- [x] **SHA-1/SHA-256 của keystore release đã đăng ký vào Firebase**
  (`sothuchi-d055a`, app Android) — Google Sign-In sẽ hoạt động đúng trên
  bản release, không bị lỗi `DEVELOPER_ERROR`.
- [x] **Xuất Excel lưu vào thư mục "Tải xuống"** (public Downloads, qua
  MediaStore) thay vì thư mục riêng của app khó tìm — đã xác nhận file
  thật sự xuất hiện trong `/storage/emulated/0/Download/` trên máy thật.

## 1. Còn thiếu / nên làm trước khi nộp

- [ ] **Deploy backend mới nhất lên Render** — vài commit gần đây (trường
  `created_by`, endpoint xoá tài khoản) chưa được deploy lên
  production. Không bắt buộc để nộp app, nhưng nên làm trước để bản nộp
  có đầy đủ tính năng.
- [ ] Chuẩn bị 1 tài khoản demo (email/mật khẩu) đã có sẵn vài giao dịch
  mẫu — cả Google và Apple đều có thể yêu cầu tài khoản test để reviewer
  đăng nhập thử.
- [ ] Icon app 512×512 (Play) / 1024×1024 (App Store) — đã có sẵn tại
  `mobile/assets/icon/icon.png`, kiểm tra độ phân giải đủ trước khi dùng.
- [ ] Chụp ảnh màn hình theo danh sách trong `docs/STORE_LISTING.md`.

## 2. Android — Google Play

### 2.1. Build bản release đã ký (đã sẵn sàng, chỉ cần chạy)

```bash
cd mobile
flutter build appbundle --release
```
File ra tại `build/app/outputs/bundle/release/app-release.aab` — đã xác
nhận ký đúng bằng `release.jks`.

> Giữ `mobile/android/app/release.jks` và `mobile/android/key.properties`
> an toàn (đã backup trên D: theo yêu cầu) — mất 1 trong 2 file này thì
> **không bao giờ** cập nhật được app dưới cùng listing trên Play Store
> nữa. Không commit chúng lên Git (đã có `.gitignore` chặn, đã kiểm tra).

### 2.2. Google Play Console

- [ ] Tạo tài khoản Google Play Developer (phí một lần **25 USD**) tại
  play.google.com/console.
- [ ] Tạo app mới, package name `com.moneyflow.mobile`.
- [ ] **Store listing**: dán nội dung từ `docs/STORE_LISTING.md`, upload
  icon + ảnh chụp màn hình.
- [ ] **Content rating questionnaire**: trả lời theo mục "Phân loại nội
  dung" trong `docs/STORE_LISTING.md`.
- [ ] **Data safety form**: khai đúng theo `docs/PRIVACY_POLICY.md` — mục
  "Personal info" (email, tên, SĐT), "Financial info" (dữ liệu giao
  dịch), chọn "Data is encrypted in transit", và **tick "users can request
  data deletion"** (đã có nút xoá tài khoản trong app).
- [ ] Dán **Privacy Policy URL**: `https://sothuchi-d055a.web.app`
- [ ] **App content** → Target audience: chọn nhóm tuổi phù hợp (không
  hướng đến trẻ em).
- [ ] Upload `.aab` vào kênh **Internal testing** trước, tự cài thử qua
  link nội bộ, xác nhận app mở được/đăng nhập được trước khi đẩy lên
  **Production**.
- [ ] Submit for review (thường 1-3 ngày với app mới).

## 3. iOS — App Store (cần máy Mac + Xcode)

Toàn bộ phần chuẩn bị không cần Mac đã xong (Firebase iOS app, Info.plist
usage strings — xem `mobile/README.md` mục "Building on macOS"). Các bước
còn lại **bắt buộc cần Mac**, không thể làm từ Windows hay từ một phiên
Claude chạy trên Chrome:

- [ ] Đăng ký **Apple Developer Program** (**99 USD/năm**) tại
  developer.apple.com.
- [ ] Trên Mac: cài Xcode, làm theo đúng 5 bước trong
  `mobile/README.md` § "Building on macOS" (mở `Runner.xcworkspace`, set
  Signing Team, thêm capability "Sign in with Apple" nếu muốn dùng, bật
  Apple provider trong Firebase Console).
- [ ] Tạo app record trong **App Store Connect**, Bundle ID
  `com.moneyflow.mobile` (phải khớp chính xác).
- [ ] Build & upload:
  ```bash
  flutter build ipa --release
  ```
  rồi mở Xcode Organizer (hoặc Apple Transporter) để upload lên App Store
  Connect.
- [ ] **App Privacy ("Nutrition label")**: khai từng mục dữ liệu dựa trên
  `docs/PRIVACY_POLICY.md` — quan trọng nhất: khai "Contact Info" (email,
  tên) và "Financial Info" (dữ liệu giao dịch) là **Linked to identity**
  nhưng **không dùng để tracking** (app không có SDK quảng cáo/analytics
  bên thứ ba nên trả lời "No" cho câu "Do you use data for tracking").
- [ ] Dán **Privacy Policy URL**: `https://sothuchi-d055a.web.app`
- [ ] Upload ảnh chụp màn hình đúng size bắt buộc (iPhone 6.7" tối thiểu).
- [ ] Test qua **TestFlight** trước khi bấm submit — mời chính bạn làm
  tester nội bộ.
- [ ] Submit for Review (thường 1-2 ngày, có thể lâu hơn ở lần nộp đầu).

## 4. Sau khi nộp

- [ ] Theo dõi trạng thái review hàng ngày (email + trong console).
- [ ] Nếu bị từ chối: đọc kỹ lý do (thường trích dẫn đúng guideline số),
  sửa, **reply trong Resolution Center** (App Store) hoặc nộp lại bản mới
  (Play) — không cần tạo listing từ đầu.
- [ ] Sau khi duyệt: giữ nguyên `release.jks`/Apple certificates cho các
  bản cập nhật sau — không tạo lại từ đầu.
