@echo off
chcp 65001 >nul
echo ================================================
echo   SETUP AI MODULE - POS ANOMALY DETECTION
echo ================================================
echo.

REM Kiểm tra Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [LOI] Python chua duoc cai dat!
    echo Vui long tai Python tai: https://python.org/downloads
    echo Nho tick "Add Python to PATH" khi cai.
    pause
    exit /b 1
)

echo [1/4] Python da san sang
python --version

echo.
echo [2/4] Dang cai cac thu vien can thiet...
pip install pandas numpy scikit-learn flask --quiet
if errorlevel 1 (
    echo [LOI] Cai thu vien that bai! Kiem tra ket noi mang.
    pause
    exit /b 1
)
echo     OK - pandas, numpy, scikit-learn, flask

echo.
echo [3/4] Dang sinh du lieu training...
python GenerateTrainingData.py
if errorlevel 1 (
    echo [LOI] Sinh du lieu that bai!
    pause
    exit /b 1
)

echo.
echo [4/4] Dang training model...
python train_model.py
if errorlevel 1 (
    echo [LOI] Training that bai!
    pause
    exit /b 1
)

echo.
echo ================================================
echo   SETUP HOAN TAT!
echo ================================================
echo.
echo De chay API, chay lenh: python predict_api.py
echo Hoac nhan phim bat ky de chay API ngay bay gio...
pause

python predict_api.py
