#!/usr/bin/env python3
"""Bootstrap the Windows toolchain and build FlClash release packages."""

from __future__ import annotations

import atexit
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import zipfile


REPO_ROOT = Path(__file__).resolve().parent
FLUTTER_RELEASES_URL = (
    'https://storage.googleapis.com/flutter_infra_release/releases/'
    'releases_windows.json'
)
FLUTTER_STORAGE_URL = 'https://storage.googleapis.com/flutter_infra_release/releases'
DEFAULT_TOOL_HOME = Path('F:/FlClashDev/FlClashBuild')
TOOL_HOME = Path(os.environ.get('FLCLASH_BUILD_HOME', DEFAULT_TOOL_HOME))
PUB_CACHE = TOOL_HOME / 'pub-cache'

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')


class BuildError(RuntimeError):
    """A user-actionable build failure."""


def log(message: str) -> None:
    print(f'[FlClash] {message}', flush=True)


def prepend_path(path: Path) -> None:
    value = str(path)
    entries = os.environ.get('PATH', '').split(os.pathsep)
    if value.casefold() not in {entry.casefold() for entry in entries}:
        os.environ['PATH'] = value + os.pathsep + os.environ.get('PATH', '')


def refresh_known_paths() -> None:
    candidates = [
        Path(os.environ.get('LOCALAPPDATA', '')) / 'Microsoft/WinGet/Links',
        Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Go/bin',
        Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/cmd',
        Path.home() / '.cargo/bin',
        PUB_CACHE / 'bin',
        Path(os.environ.get('ProgramFiles(x86)', 'C:/Program Files (x86)'))
        / 'Inno Setup 6',
    ]
    for candidate in reversed(candidates):
        if candidate.is_dir():
            prepend_path(candidate)


def display_command(command: list[str]) -> str:
    return subprocess.list2cmdline(command)


def run(
    command: list[str],
    *,
    cwd: Path = REPO_ROOT,
    check: bool = True,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    log(f'执行: {display_command(command)}')
    result = subprocess.run(
        command,
        cwd=cwd,
        env=os.environ.copy(),
        check=False,
        text=True,
        encoding='utf-8',
        errors='replace',
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )
    if capture and result.stdout:
        print(result.stdout, end='' if result.stdout.endswith('\n') else '\n')
    if check and result.returncode != 0:
        raise BuildError(
            f'命令执行失败（退出码 {result.returncode}）: '
            f'{display_command(command)}',
        )
    return result


def command_path(name: str) -> Path | None:
    resolved = shutil.which(name)
    return Path(resolved) if resolved else None


def require_winget() -> Path:
    winget = command_path('winget')
    if winget is None:
        raise BuildError(
            '未找到 winget。请先从 Microsoft Store 安装“应用安装程序”，'
            '或使用 --no-auto-install 在手动安装依赖后重试。',
        )
    return winget


def winget_install(
    package_id: str,
    *,
    override: str | None = None,
    scope: str | None = None,
) -> None:
    winget = require_winget()
    command = [
        str(winget),
        'install',
        '--id',
        package_id,
        '--exact',
        '--source',
        'winget',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--silent',
        '--disable-interactivity',
    ]
    if override:
        command.extend(['--override', override])
    if scope:
        command.extend(['--scope', scope])
    result = run(command, check=False)
    if result.returncode not in {0, 1641, 3010}:
        log(f'winget 返回 {result.returncode}，将通过重新检测依赖确认安装结果。')
    refresh_known_paths()


def ensure_command(
    name: str,
    package_id: str,
    *,
    auto_install: bool,
    extra_paths: tuple[Path, ...] = (),
) -> Path:
    for path in reversed(extra_paths):
        if path.is_dir():
            prepend_path(path)
    executable = command_path(name)
    if executable:
        log(f'{name}: {executable}')
        return executable
    if not auto_install:
        raise BuildError(f'缺少 {name}（winget 包：{package_id}）。')
    log(f'未找到 {name}，正在安装 {package_id}。')
    winget_install(package_id)
    for path in reversed(extra_paths):
        if path.is_dir():
            prepend_path(path)
    executable = command_path(name)
    if executable is None:
        raise BuildError(f'{package_id} 安装后仍未找到 {name}，请重启终端后重试。')
    return executable


def vswhere_path() -> Path:
    return (
        Path(os.environ.get('ProgramFiles(x86)', 'C:/Program Files (x86)'))
        / 'Microsoft Visual Studio/Installer/vswhere.exe'
    )


def visual_studio_cpp_path() -> Path | None:
    vswhere = vswhere_path()
    if not vswhere.is_file():
        return None
    result = subprocess.run(
        [
            str(vswhere),
            '-latest',
            '-products',
            '*',
            '-requires',
            'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
            '-property',
            'installationPath',
        ],
        check=False,
        capture_output=True,
        text=True,
        encoding='utf-8',
        errors='replace',
    )
    value = result.stdout.strip()
    return Path(value) if result.returncode == 0 and value else None


def ensure_visual_studio(auto_install: bool) -> Path:
    installation = visual_studio_cpp_path()
    if installation:
        log(f'Visual Studio C++ 工具链: {installation}')
        return installation
    if not auto_install:
        raise BuildError('缺少 Visual Studio 2022“使用 C++ 的桌面开发”工具链。')
    log('正在安装 Visual Studio 2022 C++ Build Tools（此步骤体积较大）。')
    winget_install(
        'Microsoft.VisualStudio.2022.BuildTools',
        override=(
            '--wait --passive --norestart '
            '--add Microsoft.VisualStudio.Workload.VCTools '
            '--includeRecommended'
        ),
    )
    installation = visual_studio_cpp_path()
    if installation is None:
        raise BuildError(
            'Visual Studio C++ 工具链安装后未被检测到；可能需要重启 Windows 后重试。',
        )
    return installation


def locate_winlibs_gcc() -> Path | None:
    gcc = command_path('gcc')
    if gcc:
        return gcc
    packages = (
        Path(os.environ.get('LOCALAPPDATA', '')) / 'Microsoft/WinGet/Packages'
    )
    if packages.is_dir():
        for package in packages.glob('BrechtSanders.WinLibs.POSIX.UCRT_*'):
            matches = list(package.glob('**/mingw64/bin/gcc.exe'))
            if matches:
                prepend_path(matches[0].parent)
                return matches[0]
    migrated = Path('F:/FlClashDev/WinLibs/mingw64/bin/gcc.exe')
    if migrated.is_file():
        prepend_path(migrated.parent)
        return migrated
    return None


def ensure_gcc(auto_install: bool) -> Path:
    gcc = locate_winlibs_gcc()
    if gcc:
        log(f'gcc: {gcc}')
        return gcc
    if not auto_install:
        raise BuildError('缺少 GCC（winget 包：BrechtSanders.WinLibs.POSIX.UCRT）。')
    log('未找到 GCC，正在安装 WinLibs。')
    winget_install('BrechtSanders.WinLibs.POSIX.UCRT')
    gcc = locate_winlibs_gcc()
    if gcc is None:
        raise BuildError('WinLibs 安装后仍未找到 gcc。')
    return gcc


def locate_inno() -> Path | None:
    iscc = command_path('iscc')
    if iscc:
        return iscc
    roots = (
        Path(os.environ.get('ProgramFiles(x86)', 'C:/Program Files (x86)')),
        Path(os.environ.get('ProgramFiles', 'C:/Program Files')),
        Path(os.environ.get('LOCALAPPDATA', '')) / 'Programs',
    )
    for root in roots:
        candidate = root / 'Inno Setup 6/ISCC.exe'
        if candidate.is_file():
            prepend_path(candidate.parent)
            return candidate
    return None


def ensure_inno(auto_install: bool) -> Path:
    iscc = locate_inno()
    packager_path = Path('C:/Program Files (x86)/Inno Setup 6/ISCC.exe')
    if packager_path.is_file():
        prepend_path(packager_path.parent)
        log(f'Inno Setup: {packager_path}')
        return packager_path
    if iscc and not auto_install:
        raise BuildError(
            f'Inno Setup 位于 {iscc}，但 flutter_distributor 只识别 '
            'C:\\Program Files (x86)\\Inno Setup 6；请以管理员身份安装 all-users 版本。',
        )
    if iscc:
        log(f'Inno Setup: {iscc}')
    if not auto_install:
        raise BuildError('缺少 Inno Setup 6（winget 包：JRSoftware.InnoSetup）。')
    log('正在以 all-users 模式安装 Inno Setup。')
    winget_install(
        'JRSoftware.InnoSetup',
        override='/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS',
        scope='machine',
    )
    if not packager_path.is_file():
        raise BuildError(
            'Inno Setup 安装后未出现在 flutter_distributor 所需的默认目录。',
        )
    return packager_path


def ci_flutter_version() -> str:
    workflow = REPO_ROOT / '.github/workflows/build.yaml'
    if workflow.is_file():
        match = re.search(
            r'^\s*FLUTTER_VERSION:\s*[\'\"]([^\'\"]+)[\'\"]',
            workflow.read_text(encoding='utf-8'),
            flags=re.MULTILINE,
        )
        if match:
            return match.group(1)
    raise BuildError('无法从 .github/workflows/build.yaml 读取 Flutter 版本。')


def flutter_version(executable: Path) -> str | None:
    # The first Flutter invocation can populate its cache before emitting JSON.
    for _ in range(2):
        result = subprocess.run(
            [str(executable), '--version', '--machine'],
            cwd=REPO_ROOT,
            env=os.environ.copy(),
            check=False,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
        )
        if result.returncode != 0:
            continue
        json_start = result.stdout.find('{')
        if json_start < 0:
            continue
        try:
            return str(json.loads(result.stdout[json_start:])['frameworkVersion'])
        except (KeyError, TypeError, json.JSONDecodeError):
            continue
    return None


def host_flutter_arch() -> str:
    machine = platform.machine().lower()
    return 'arm64' if machine in {'arm64', 'aarch64'} else 'x64'


def release_metadata(version: str) -> dict[str, str]:
    log(f'读取 Flutter {version} 官方发行信息。')
    try:
        with urllib.request.urlopen(FLUTTER_RELEASES_URL, timeout=60) as response:
            metadata = json.load(response)
    except (OSError, ValueError) as error:
        raise BuildError(f'无法获取 Flutter 发行信息: {error}') from error
    architecture = host_flutter_arch()
    for release in metadata.get('releases', []):
        if release.get('version') != version:
            continue
        archive = str(release.get('archive', ''))
        release_arch = str(release.get('dart_sdk_arch', 'x64'))
        if archive.endswith('.zip') and release_arch == architecture:
            return {
                'archive': archive,
                'sha256': str(release['sha256']),
            }
    raise BuildError(f'官方发行列表中没有 Windows {architecture} Flutter {version}。')


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def configure_github_mirror(base_url: str) -> None:
    if base_url.casefold() == 'direct':
        os.environ.pop('GIT_CONFIG_COUNT', None)
        os.environ.pop('GIT_CONFIG_KEY_0', None)
        os.environ.pop('GIT_CONFIG_VALUE_0', None)
        log('GitHub Git 流量使用直连。')
        return
    normalized = base_url.rstrip('/') + '/'
    os.environ['GIT_CONFIG_COUNT'] = '1'
    os.environ['GIT_CONFIG_KEY_0'] = f'url.{normalized}.insteadOf'
    os.environ['GIT_CONFIG_VALUE_0'] = 'https://github.com/'
    log(f'GitHub Git 镜像: {normalized}')


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + '.part')
    log(f'下载: {url}')
    try:
        with urllib.request.urlopen(url, timeout=120) as response, temporary.open(
            'wb',
        ) as output:
            total = int(response.headers.get('Content-Length', '0'))
            received = 0
            next_report = 10
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
                received += len(chunk)
                if total and received * 100 // total >= next_report:
                    log(f'Flutter SDK 下载进度: {received * 100 // total}%')
                    next_report += 10
        temporary.replace(destination)
    except OSError as error:
        temporary.unlink(missing_ok=True)
        raise BuildError(f'下载失败: {error}') from error


def safe_extract(archive: Path, destination: Path) -> None:
    destination_resolved = destination.resolve()
    with zipfile.ZipFile(archive) as source:
        for member in source.infolist():
            member_path = (destination / member.filename).resolve()
            if os.path.commonpath([destination_resolved, member_path]) != str(
                destination_resolved,
            ):
                raise BuildError(f'Flutter 压缩包包含不安全路径: {member.filename}')
        source.extractall(destination)


def install_flutter(version: str) -> Path:
    release = release_metadata(version)
    archive_name = Path(release['archive']).name
    archive = TOOL_HOME / 'downloads' / archive_name
    if not archive.is_file() or sha256_file(archive) != release['sha256']:
        archive.unlink(missing_ok=True)
        download(f"{FLUTTER_STORAGE_URL}/{release['archive']}", archive)
    if sha256_file(archive) != release['sha256']:
        archive.unlink(missing_ok=True)
        raise BuildError('Flutter SDK SHA256 校验失败，已删除损坏的下载文件。')

    versions_root = TOOL_HOME / 'flutter'
    target = versions_root / version
    versions_root.mkdir(parents=True, exist_ok=True)
    log(f'解压 Flutter SDK 到 {target}')
    with tempfile.TemporaryDirectory(dir=versions_root, prefix='extract-') as temp:
        temporary = Path(temp)
        safe_extract(archive, temporary)
        extracted = temporary / 'flutter'
        if not (extracted / 'bin/flutter.bat').is_file():
            raise BuildError('Flutter SDK 压缩包结构不符合预期。')
        if target.exists():
            shutil.rmtree(target)
        shutil.move(str(extracted), str(target))
    return target / 'bin/flutter.bat'


def ensure_flutter(version: str, auto_install: bool) -> Path:
    local = TOOL_HOME / 'flutter' / version / 'bin/flutter.bat'
    candidates = [local]
    global_flutter = command_path('flutter')
    if global_flutter:
        candidates.append(global_flutter)
    for candidate in candidates:
        if candidate.is_file():
            prepend_path(candidate.parent)
            detected = flutter_version(candidate)
            if detected == version:
                log(f'Flutter {detected}: {candidate}')
                return candidate
            log(f'忽略 Flutter {detected or "未知版本"}: {candidate}')
    if not auto_install:
        raise BuildError(f'缺少 CI 指定的 Flutter {version}。')
    flutter = install_flutter(version)
    prepend_path(flutter.parent)
    if flutter_version(flutter) != version:
        raise BuildError('Flutter 安装完成，但版本验证失败。')
    return flutter


def ensure_dependencies(
    *,
    auto_install: bool,
    flutter_version_value: str,
    targets: set[str],
) -> tuple[Path, Path]:
    refresh_known_paths()
    ensure_command(
        'git',
        'Git.Git',
        auto_install=auto_install,
        extra_paths=(Path('C:/Program Files/Git/cmd'),),
    )
    ensure_command(
        'go',
        'GoLang.Go',
        auto_install=auto_install,
        extra_paths=(Path('C:/Program Files/Go/bin'),),
    )
    ensure_gcc(auto_install)
    ensure_visual_studio(auto_install)
    rustup = ensure_command(
        'rustup',
        'Rustlang.Rustup',
        auto_install=auto_install,
        extra_paths=(Path.home() / '.cargo/bin',),
    )
    ensure_command(
        'cargo',
        'Rustlang.Rustup',
        auto_install=auto_install,
        extra_paths=(Path.home() / '.cargo/bin',),
    )
    if 'exe' in targets:
        ensure_inno(auto_install)
    flutter = ensure_flutter(flutter_version_value, auto_install)
    dart = flutter.parent / 'dart.bat'
    if not dart.is_file():
        raise BuildError(f'Flutter SDK 中未找到 Dart: {dart}')

    if auto_install:
        run([str(rustup), 'default', 'stable'])
        rust_target = (
            'aarch64-pc-windows-msvc'
            if host_flutter_arch() == 'arm64'
            else 'x86_64-pc-windows-msvc'
        )
        run([str(rustup), 'target', 'add', rust_target])
    return flutter, dart


def verify_repo() -> None:
    if not (REPO_ROOT / 'pubspec.yaml').is_file() or not (
        REPO_ROOT / 'setup.dart'
    ).is_file():
        raise BuildError(f'脚本不在有效的 FlClash 仓库中: {REPO_ROOT}')


def ensure_build_workspace() -> Path:
    if re.fullmatch(r'[A-Za-z0-9._-]+', REPO_ROOT.name) is None:
        raise BuildError(f'仓库目录名必须使用纯 ASCII 安全字符: {REPO_ROOT.name}')
    drive_mask = ctypes.windll.kernel32.GetLogicalDrives()
    for letter in reversed('PQRSTUVWXYZ'):
        drive_root = Path(f'{letter}:/')
        workspace = drive_root / REPO_ROOT.name
        try:
            if workspace.is_dir() and os.path.samefile(workspace, REPO_ROOT):
                log(f'构建工作区: {workspace}')
                return workspace
        except OSError:
            pass
        drive_index = ord(letter) - ord('A')
        if drive_mask & (1 << drive_index):
            continue
        drive = f'{letter}:'
        result = subprocess.run(
            ['subst.exe', drive, str(REPO_ROOT.parent)],
            check=False,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
        )
        if result.returncode != 0:
            continue
        try:
            matches_repo = workspace.is_dir() and os.path.samefile(
                workspace,
                REPO_ROOT,
            )
        except OSError:
            matches_repo = False
        if not matches_repo:
            subprocess.run(['subst.exe', drive, '/D'], check=False)
            continue

        def release_workspace(mapped_drive: str = drive) -> None:
            subprocess.run(
                ['subst.exe', mapped_drive, '/D'],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

        atexit.register(release_workspace)
        log(f'构建工作区: {workspace}')
        return workspace
    raise BuildError('无法分配 P: 到 Z: 范围内的 ASCII 构建盘符。')


def reset_windows_build_state(build_root: Path) -> None:
    generated_path = REPO_ROOT / 'build/windows'
    cache_path = generated_path / 'x64/CMakeCache.txt'
    if not cache_path.is_file():
        return
    try:
        cache = cache_path.read_text(encoding='utf-8', errors='replace')
    except OSError as error:
        raise BuildError(f'无法读取 Windows 原生构建缓存: {error}') from error
    expected_source = (build_root / 'windows').as_posix().lower()
    cached_source = next(
        (
            line.partition('=')[2].strip().replace('\\', '/').lower()
            for line in cache.splitlines()
            if line.startswith('CMAKE_HOME_DIRECTORY:INTERNAL=')
        ),
        '',
    )
    if cached_source == expected_source:
        return
    log(f'清理过期 Windows 原生构建缓存: {generated_path}')
    try:
        shutil.rmtree(generated_path)
    except OSError as error:
        raise BuildError(
            f'无法清理 Windows 原生构建缓存: {error}',
        ) from error


def list_artifacts() -> None:
    output = REPO_ROOT / 'dist'
    artifacts = sorted(path for path in output.glob('*') if path.is_file())
    if not artifacts:
        raise BuildError('构建命令成功，但 dist/ 中没有找到产物。')
    log('构建完成，产物如下：')
    for artifact in artifacts:
        size_mb = artifact.stat().st_size / 1024 / 1024
        print(f'  {artifact} ({size_mb:.1f} MiB)')
        print(f'    SHA256: {sha256_file(artifact)}')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            '自动安装 Windows 构建依赖，并通过仓库 setup.dart 生成 FlClash 安装包。'
        ),
    )
    parser.add_argument(
        '--env',
        choices=('pre', 'stable'),
        default='pre',
        help='应用环境（默认: pre）',
    )
    parser.add_argument(
        '--targets',
        default='exe',
        help='逗号分隔的打包目标（默认: exe）',
    )
    parser.add_argument(
        '--flutter-version',
        help='Flutter 版本；默认读取 GitHub Actions 的 FLUTTER_VERSION',
    )
    parser.add_argument(
        '--go-proxy',
        default=os.environ.get('GOPROXY', 'https://goproxy.cn,direct'),
        help='Go 模块代理（默认: https://goproxy.cn,direct）',
    )
    parser.add_argument(
        '--github-mirror',
        default='direct',
        help='GitHub Git 镜像；传 direct 禁用（默认: direct）',
    )
    parser.add_argument(
        '--retries',
        type=int,
        default=3,
        help='最终打包遇到临时网络错误时的尝试次数（默认: 3）',
    )
    parser.add_argument(
        '--no-auto-install',
        action='store_true',
        help='缺少依赖时直接报错，不调用 winget 或下载 Flutter',
    )
    parser.add_argument(
        '--check-only',
        action='store_true',
        help='只检查依赖，不安装、不构建',
    )
    parser.add_argument(
        '--install-only',
        action='store_true',
        help='只安装并验证依赖，不构建',
    )
    parser.add_argument(
        '--skip-generation',
        action='store_true',
        help='跳过 intl_utils 和 build_runner 代码生成',
    )
    parser.add_argument(
        '--skip-pub-get',
        action='store_true',
        help='跳过 flutter pub get',
    )
    parser.add_argument(
        '--skip-submodules',
        action='store_true',
        help='跳过 git submodule update --init --recursive',
    )
    parser.add_argument(
        '--verbose',
        '-v',
        action='store_true',
        help='将详细构建输出传给 setup.dart',
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    verify_repo()
    if os.name != 'nt':
        raise BuildError('此脚本只能在 Windows 上运行。')

    targets = {item.strip() for item in args.targets.split(',') if item.strip()}
    if not targets:
        raise BuildError('--targets 不能为空。')
    if args.retries < 1:
        raise BuildError('--retries 必须大于或等于 1。')
    version = args.flutter_version or ci_flutter_version()
    os.environ['PUB_CACHE'] = str(PUB_CACHE)
    os.environ['GOPROXY'] = args.go_proxy
    migrated_cargo = Path('F:/FlClashDev/cargo')
    migrated_rustup = Path('F:/FlClashDev/rustup')
    migrated_go_cache = Path('F:/FlClashDev/go-build')
    migrated_go_path = Path('F:/FlClashDev/go')
    if migrated_cargo.is_dir():
        os.environ['CARGO_HOME'] = str(migrated_cargo)
        prepend_path(migrated_cargo / 'bin')
    if migrated_rustup.is_dir():
        os.environ['RUSTUP_HOME'] = str(migrated_rustup)
    if migrated_go_cache.is_dir():
        os.environ['GOCACHE'] = str(migrated_go_cache)
    if migrated_go_path.is_dir():
        os.environ['GOPATH'] = str(migrated_go_path)
    configure_github_mirror(args.github_mirror)
    # MSVC/Cargo can otherwise emit GBK on Chinese Windows, while the repo's
    # Dart build tool consumes child-process output as UTF-8.
    os.environ['VSLANG'] = '1033'
    os.environ['LANG'] = 'en_US.UTF-8'
    os.environ['LC_ALL'] = 'C'
    PUB_CACHE.mkdir(parents=True, exist_ok=True)
    prepend_path(PUB_CACHE / 'bin')

    auto_install = not args.no_auto_install and not args.check_only
    flutter, dart = ensure_dependencies(
        auto_install=auto_install,
        flutter_version_value=version,
        targets=targets,
    )
    log('Windows 构建依赖检查通过。')
    if args.check_only or args.install_only:
        return 0

    build_root = ensure_build_workspace()
    reset_windows_build_state(build_root)

    if not args.skip_submodules:
        run(['git', 'config', 'core.longpaths', 'true'], cwd=build_root)
        run(
            ['git', 'submodule', 'update', '--init', '--recursive'],
            cwd=build_root,
        )
    run(
        [str(flutter), 'config', '--enable-windows-desktop'],
        cwd=build_root,
    )
    if not args.skip_pub_get:
        run([str(flutter), 'pub', 'get'], cwd=build_root)
    if not args.skip_generation:
        run([str(dart), 'run', 'intl_utils:generate'], cwd=build_root)
        run(
            [
                str(dart),
                'run',
                'build_runner',
                'build',
                '--delete-conflicting-outputs',
            ],
            cwd=build_root,
        )

    setup_command = [
        str(dart),
        'setup.dart',
        'windows',
        '--env',
        args.env,
        '--targets',
        ','.join(sorted(targets)),
    ]
    if args.verbose:
        setup_command.append('--verbose')
    package_succeeded = False
    for attempt in range(1, args.retries + 1):
        result = run(setup_command, check=False, cwd=build_root)
        if result.returncode == 0:
            package_succeeded = True
            break
        if attempt == args.retries:
            raise BuildError(
                f'Windows 打包在 {args.retries} 次尝试后仍失败'
                f'（退出码 {result.returncode}）。',
            )
        delay = attempt * 5
        log(
            f'打包尝试 {attempt}/{args.retries} 失败，将在 {delay} 秒后重试。',
        )
        time.sleep(delay)
    if not package_succeeded:
        raise BuildError('Windows 打包失败。')
    list_artifacts()
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        log('操作已取消。')
        raise SystemExit(130) from None
    except BuildError as error:
        print(f'[FlClash] 错误: {error}', file=sys.stderr, flush=True)
        raise SystemExit(1) from None
