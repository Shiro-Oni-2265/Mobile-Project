# Hợp đồng REST và xử lý lỗi

## Cấu hình

Backend là json-server **0.17.4**, cổng **3000**. App đọc API_BASE_URL từ cấu hình biên dịch, không đặt URL trực tiếp trong View. Dùng file ví dụ app/config/dev.example.json cho Android emulator, ios.example.json cho simulator và device.example.json để sửa thành LAN IP thật.

| Môi trường | API_BASE_URL |
|---|---|
| Android emulator | http://10.0.2.2:3000 |
| iOS simulator | http://localhost:3000 |
| Thiết bị thật | http://IP-LAN-MAY-CHU:3000 |

Máy thật phải cùng mạng với backend, backend lắng nghe mạng phù hợp và firewall cho phép cổng 3000. localhost trên điện thoại không phải máy tính. Flavor Android demo cho phép HTTP; bản thông thường giữ chính sách HTTP hạn chế.

## Khởi động và dữ liệu backend

Trong backend chạy npm ci rồi npm start. Lần đầu, runtime/db.json được tạo từ seed.json. Runtime bị Git bỏ qua, nên các thay đổi thử nghiệm không làm bẩn seed. backend/db.json giữ bản dữ liệu theo quy ước starter; seed.json là dữ liệu khởi tạo của launcher.

Dừng API trước khi npm run reset; lệnh này chủ động đưa runtime về seed và làm mất thay đổi demo. Không dùng reset khi cần giữ dữ liệu người dùng thử. scripts/api.ps1 hỗ trợ start, stop, logs, reset và chọn auto/docker/node; xem README cho ví dụ.

## Endpoint ứng dụng sử dụng

Không có auth, Bearer token, userId hay quyền sở hữu riêng trên máy chủ.

| Method | Đường dẫn | Kết quả thông thường | Vai trò |
|---|---|---|---|
| GET | /recipes | 200, mảng JSON | Danh mục công thức |
| GET | /recipes/:id | 200, object; 404 nếu thiếu | Chi tiết/kiểm tra ID sau thao tác không chắc chắn |
| POST | /recipes | 201, object đã lưu | Công thức mới/bản sao, UUID do client tạo |
| PUT | /recipes/:id | 200, object | Thay toàn bộ công thức cùng ID |
| DELETE | /recipes/:id | 200 theo json-server 0.17.4 | Xóa món thường |
| GET | /ingredients | 200, mảng JSON | Danh mục nguyên liệu |
| GET | /ingredients/:id | 200, object; 404 nếu thiếu | Kiểm tra ID khi ghi/nhập lại |
| POST | /ingredients | 201, object | Thêm nguyên liệu |
| PUT | /ingredients/:id | 200, object | Cập nhật nguyên liệu |

Không có endpoint đồng bộ thực đơn, tủ lạnh, mua sắm, tùy chọn, yêu thích hoặc ảnh. json-server là mock không có kiểm soát truy cập; khóa sample ở UI không bảo vệ server khỏi người gọi HTTP trực tiếp.

## JSON chính

```json
{
  "id": "uuid-do-client-tao",
  "name": "Trứng xào cà chua",
  "description": "Món nhanh",
  "category": "Món chính",
  "minutes": 15,
  "servings": 2,
  "vegetarian": false,
  "sample": false,
  "items": [
    {"ingredientId": "egg", "amount": 2, "unit": "quả"}
  ],
  "steps": ["Sơ chế nguyên liệu", "Nấu chín và dùng nóng"]
}
```

Ví dụ minh họa cấu trúc, không khẳng định ID egg tồn tại trong seed hiện hành. Recipe.items phải tham chiếu ID nguyên liệu trong danh mục. amount=null nghĩa là chưa định lượng/vừa đủ.

```json
{
  "id": "uuid-nguyen-lieu",
  "name": "Nguyên liệu ví dụ",
  "per100g": {"kcal": 100, "protein": 10, "carbs": 5, "fat": 4},
  "gramsPerPiece": null,
  "source": "Dữ liệu minh họa, cần kiểm chứng"
}
```

per100g hoặc gramsPerPiece có thể null. Số dinh dưỡng ví dụ không phải số liệu thực phẩm được xác nhận. Đường dẫn ảnh local và yêu thích không thuộc payload chia sẻ; localImages và favoriteIds thuộc Notebook trên máy.

PUT là thay toàn bộ object, không phải PATCH từng trường. Giữ ID hiện tại khi cập nhật; sao chép phải dùng ID mới và sample=false.

## Timeout, lỗi và retry

RecipeApi đặt timeout **15 giây**. Controller nhận AppFailure phù hợp và hiển thị lỗi có retry. Refresh GET có thể thử lại theo yêu cầu người dùng, giữ cache cũ nếu thất bại; không dùng seed đóng gói để giả kết quả mạng.

| Lỗi | Hành vi cần thấy |
|---|---|
| Sai cấu hình URL | Thông báo cấu hình; sửa file define và chạy lại |
| Không mạng/socket hoặc timeout | Cảnh báo, giữ cache; retry đọc |
| HTTP ngoài 2xx | Không báo ghi thành công; thông báo lỗi |
| 404 chi tiết | Phân biệt món không tồn tại với lỗi kết nối |
| JSON sai kiểu/hỏng | Báo không đọc được dữ liệu; không ghi đè cache bằng nội dung hỏng |
| SQLite lỗi | Báo lỗi lưu/đọc; không che bằng thông báo thành công |

Không tự retry POST/PUT/DELETE. Timeout có thể xảy ra sau khi server đã ghi. Giữ ID, GET kiểm tra hoặc refresh trước khi thực hiện lại, tránh tạo bản sao ngoài ý muốn. Đây là tính chất “kết quả chưa biết”, không thể kết luận server chưa lưu chỉ từ timeout.

## Kiểm tra thủ công API

```powershell
Invoke-RestMethod http://localhost:3000/recipes
Invoke-RestMethod http://localhost:3000/ingredients
```

Thử ghi bằng dữ liệu demo trên runtime riêng, rồi kiểm tra GET và xem app sau refresh. Các lệnh trên là hướng dẫn, không phải log kết quả. Bằng chứng chạy nằm ở testing-guide sau khi thực sự kiểm tra.
