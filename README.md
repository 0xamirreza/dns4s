# DNS4S

ابزار خط فرمان سبک برای مدیریت DNS در لینوکس. DNS4S به‌صورت خودکار backend فعال سیستم را تشخیص می‌دهد و یکی از این روش‌ها را استفاده می‌کند:

- `systemd-resolved`
- `NetworkManager`
- فایل `/etc/resolv.conf` به‌عنوان روش جایگزین

## پیش‌نیازها

- Linux
- Bash
- برای تغییر تنظیمات: دسترسی `root` یا `sudo`
- آدرس‌های IPv4 معتبر

وابستگی‌های اختیاری:

- `resolvectl` و سرویس `systemd-resolved`
- `nmcli` و سرویس فعال `NetworkManager`

## نصب روی سرور

```bash
git clone <repository-url>
cd DNS4S
chmod +x dns4s
sudo install -m 755 dns4s /usr/local/bin/dns4s
```

اگر فایل را با `scp` منتقل می‌کنید:

```bash
scp dns4s user@SERVER_IP:/tmp/dns4s
ssh user@SERVER_IP
sudo install -m 755 /tmp/dns4s /usr/local/bin/dns4s
```

بررسی نصب:

```bash
dns4s --help
dns4s status
```

## استفاده

### مشاهده وضعیت DNS

```bash
dns4s status
```

### تنظیم DNS

دو DNS اصلی و یک DNS جایگزین وارد کنید:

```bash
sudo dns4s set \
  --dns 1.1.1.1,8.8.8.8 \
  --fallback 9.9.9.9
```

نمونه دیگر:

```bash
sudo dns4s set \
  --dns 178.22.122.101,185.51.200.1 \
  --fallback 9.9.9.9
```

تمام آدرس‌ها قبل از اعمال بررسی می‌شوند و باید IPv4 معتبر باشند.

### بازگردانی تنظیمات

```bash
sudo dns4s reset
```

در حالت `/etc/resolv.conf`، قبل از تغییر فایل معمولی یک نسخه پشتیبان در مسیر زیر ساخته می‌شود:

```text
/etc/resolv.conf.dns4s-backup
```

## رفتار backendها

### systemd-resolved

فایل `/etc/systemd/resolved.conf` تنظیم و سرویس `systemd-resolved` دوباره راه‌اندازی می‌شود. مقدار `--fallback` در این backend استفاده می‌شود.

### NetworkManager

اولین connection فعال پیدا می‌شود، DNS خودکار غیرفعال و DNSهای واردشده تنظیم می‌شوند. گزینه `--fallback` در NetworkManager معادل مستقیمی ندارد.

### `/etc/resolv.conf`

فایل با دو خط `nameserver` بازنویسی می‌شود. ممکن است سرویس دیگری این فایل را بعداً بازنویسی کند.

## نکات مهم سرور

- اجرای `set` تنظیمات DNS سیستم را تغییر می‌دهد و ممکن است اتصال شبکه یا SSH را مختل کند.
- پیش از تغییر، از دسترسی کنسول یا مسیر پشتیبان برای ورود به سرور مطمئن شوید.
- DNS4S فقط IPv4 را پشتیبانی می‌کند.
- در NetworkManager فقط اولین connection فعال تغییر می‌کند.
- این پروژه سرویس دائمی یا وب‌سرور نیست؛ یک CLI است و نیازی به اجرای آن روی پورت ندارد.

## مجوز

MIT License
