IF EXIST ".\venv" (
  call .\venv\Scripts\activate.bat
) ELSE (
  IF EXIST "..\.venv" ( 
    rem try to activate venv from root directory (VS Code default)
    call ..\.venv\Scripts\activate.bat
  ) ELSE (
    echo "venv not found. Please create a virtual environment and activate it."
    pause >nul
    exit
  )
)
echo activated python venv.

pip install -r requirements.txt
echo installed python requirements.

if not %1=="-nopause" (
  pause >nul
) 