# Nguồn gốc mã và dữ liệu NauGi

## Nguồn đã nhập

- Repository nguồn: [lesyeuxdelamour/demo](https://github.com/lesyeuxdelamour/demo.git).
- Commit dùng làm mốc: `9a776ee0932dea678e1ddfd77175013e2d8b37ab`.
- Bản checkout tham chiếu cục bộ: `.tools/naugi-source/`.
- Mã Flutter nhập vào `app/`; catalog nguồn là cơ sở xuất seed backend.
- Lịch sử nguồn được fetch vào ref cục bộ `refs/remotes/naugi-source/main` và nối vào nhánh chuyển đổi bằng merge `ours` ở commit `f6f4988`. Merge này giữ toàn bộ ancestry của NauGi mà không ghi đè cấu trúc bài tập. Một bản clone Git của nhánh sau merge vẫn truy cập được commit nguồn `9a776ee`.

Giữ thư mục nguồn tham chiếu tách khỏi app đang phát triển. Không coi việc nhập một snapshot là bằng chứng các thành viên đã tự viết toàn bộ mã nguồn.

## Nội dung kế thừa và thay đổi cho đồ án

Kế thừa giao diện tiếng Việt, mô hình công thức/thực đơn/tủ lạnh/mua sắm, logic định lượng/dinh dưỡng/gợi ý và tích hợp ảnh/nhắc hạn. Bản đồ án chuyển nguồn remote sang REST json-server, tách repository, cache và 4 trạng thái, bỏ tài khoản/Supabase/Google và bổ sung cấu hình, script, kiểm thử, tài liệu theo INT1449.

Danh mục công thức/nguyên liệu seed lấy từ catalog nguồn qua exporter, không phải dữ liệu do API thương mại cung cấp. Giá trị dinh dưỡng chỉ là dữ liệu của catalog; chưa có xác nhận độc lập về độ chính xác hoặc tư vấn sức khỏe.

Không sao chép tuyên bố “đã test”, “đã build”, phiên bản hoặc ảnh demo từ README nguồn thành bằng chứng bản đồ án. Kết quả phải gắn với thực thi trên mã hiện tại và ghi trong testing-guide.

## Kiểm tra nguồn và quyền sử dụng

Nhóm cần kiểm tra file LICENSE/điều khoản thực tế tại commit nguồn, nguồn gốc ảnh/dữ liệu và quyền sử dụng trước khi phân phối. Việc repository có thể đọc công khai không tự có nghĩa là được cấp mọi quyền tái sử dụng. Tài liệu này không tự gán giấy phép cho phần mã kế thừa.

Khi nộp, giữ dẫn nguồn này, AI Disclosure và AI log. Không đưa secret, tài khoản thử thật hoặc dữ liệu cá nhân từ dự án nguồn vào đồ án.

## Cách đối chiếu

```powershell
git show 9a776ee0932dea678e1ddfd77175013e2d8b37ab --stat
git log refs/remotes/naugi-source/main --oneline -5
git diff -- app docs backend
```

Trong bản clone mới của nhánh đã merge, `git show 9a776ee` và `git log 9a776ee` hoạt động nhờ ancestry; ref `refs/remotes/naugi-source/main` chỉ tồn tại ở máy thực hiện chuyển đổi. Đối chiếu bằng diff theo file, không suy ra tác giả hoặc tỷ lệ đóng góp từ số dòng.
