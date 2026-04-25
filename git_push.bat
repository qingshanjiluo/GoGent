@echo off
chcp 65001 >nul
title GoGent - Git 快捷上传

echo ========================================
echo   GoGent - Git 快捷上传工具
echo ========================================
echo.

:: 设置项目路径（当前目录）
set PROJECT_DIR=%CD%
cd /d "%PROJECT_DIR%"

:: 检查是否是 Git 仓库
if not exist ".git" (
    echo [错误] 当前目录不是 Git 仓库！
    echo 请将本 bat 文件放在 GoGent 项目根目录下运行。
    pause
    exit /b 1
)

:: 输入提交信息
set /p COMMIT_MSG="请输入提交信息（直接回车使用默认信息）: "
if "%COMMIT_MSG%"=="" (
    for /f "tokens=1-3 delims=/- " %%a in ('echo %date%') do (
        set TODAY=%%a-%%b-%%c
    )
    set COMMIT_MSG=Auto commit %TODAY% %time:~0,5%
)

echo.
echo [1/4] 检查文件状态...
git status --short
echo.

:: 询问是否添加所有文件
set /p ADD_ALL="是否添加所有更改？(Y/n): "
if /i "%ADD_ALL%"=="n" (
    echo 跳过添加步骤，请手动 git add 后重新运行。
    pause
    exit /b 0
)

echo [2/4] 添加所有更改...
git add -A
if %errorlevel% neq 0 (
    echo [错误] git add 失败！
    pause
    exit /b %errorlevel%
)
echo 完成！

echo [3/4] 提交更改...
git commit -m "%COMMIT_MSG%"
if %errorlevel% neq 0 (
    echo [错误] git commit 失败！
    pause
    exit /b %errorlevel%
)
echo 完成！

echo [4/4] 推送到远程仓库...
git push origin main
if %errorlevel% neq 0 (
    echo.
    echo [重试] 尝试推送到 master 分支...
    git push origin master
    if %errorlevel% neq 0 (
        echo [错误] git push 失败！
        echo 可能原因：
        echo   1. 网络连接问题
        echo   2. 远程仓库地址错误
        echo   3. 没有推送权限
        echo.
        echo 当前远程仓库：
        git remote -v
        pause
        exit /b %errorlevel%
    )
)

echo.
echo ========================================
echo   ✓ 上传成功！
echo ========================================
echo   提交信息: %COMMIT_MSG%
echo   时间: %date% %time%
echo ========================================

pause
