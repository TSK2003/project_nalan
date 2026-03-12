# Free Cloud Deployment

This project now supports two app modes:

- `offline` (default): uses local device storage
- `cloud`: uses the FastAPI backend

## Recommended free stack

For a no-cost setup that is realistic for testing:

- Backend: Render free web service
- Database: Supabase free Postgres project

For temporary public demos without deploying a server:

- Run the backend locally
- Expose it with a Cloudflare Quick Tunnel

## 1. Deploy the backend

Use the `Dockerfile` in this folder on a free web host that supports Docker.

Required environment variables:

- `DATABASE_URL`
- `JWT_SECRET_KEY`
- `JWT_ALGORITHM`
- `ACCESS_TOKEN_EXPIRE_MINUTES`
- `REFRESH_TOKEN_EXPIRE_DAYS`
- `HOTEL_NAME`
- `HOTEL_UPI_ID`
- `HOTEL_ADDRESS`
- `HOTEL_PHONE`
- `HOTEL_GSTIN`
- `CURRENCY_SYMBOL`
- `BILL_PREFIX`
- `UPI_POLL_INTERVAL`
- `UPI_POLL_TIMEOUT`
- `MAX_DISCOUNT_PCT`

Start command inside the container:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Health endpoint:

```text
/health
```

## 2. Use a free Postgres database

Point `DATABASE_URL` to your hosted Postgres instance.

Example:

```text
postgresql://USER:PASSWORD@HOST:5432/DBNAME
```

## 3. Build the Android app in cloud mode

From the Flutter app root:

```bash
/home/karthick-s/flutter/bin/flutter build apk --release --dart-define=APP_MODE=cloud --dart-define=API_BASE_URL=https://YOUR-BACKEND-URL
```

## 4. Run locally in cloud mode for testing

```bash
/home/karthick-s/flutter/bin/flutter run --dart-define=APP_MODE=cloud --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Notes

- Offline mode remains the default if `APP_MODE` is not set.
- The current UI supports both modes through the same screens.
- For a real multi-device setup, deploy the backend first and then rebuild the APK in cloud mode.
- Render free web services spin down on idle, so the first request after inactivity will be slow.
- Render free local files are ephemeral, so use hosted Postgres instead of SQLite.
- Cloudflare Quick Tunnel is only for testing and development.
