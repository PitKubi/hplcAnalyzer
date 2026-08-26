# Building Windows Desktop App

## Quick Build Instructions

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Build the React app:**
   ```bash
   npm run build
   ```

3. **Create Windows installer:**
   ```bash
   npm run electron-pack
   ```

4. **Find your app:**
   - The Windows installer (.exe) will be in the `dist` folder
   - Install it on any Windows machine
   - Creates desktop and start menu shortcuts

## Development Mode

To run in development mode:
```bash
npm start
# In another terminal:
npm run electron-dev
```

## What You Get

- **Single .exe installer** for Windows
- **Desktop shortcut** automatically created
- **Start menu entry** for easy access
- **Professional app** with your name in the title and footer
- **No dependencies** needed on target machines

The app will look exactly like the web version but as a native Windows desktop application!


