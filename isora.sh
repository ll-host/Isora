#!/usr/bin/env bash

set -uo pipefail

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY="ll-host/Isora"
readonly DIST_DIR="${PROJECT_ROOT}/dist"

if [[ -t 1 ]]; then
    readonly BOLD=$'\033[1m'
    readonly BLUE=$'\033[38;5;75m'
    readonly GREEN=$'\033[38;5;78m'
    readonly RED=$'\033[38;5;203m'
    readonly DIM=$'\033[2m'
    readonly RESET=$'\033[0m'
else
    readonly BOLD='' BLUE='' GREEN='' RED='' DIM='' RESET=''
fi

pause_menu() {
    printf '\n'
    read -r -p 'Нажмите Enter, чтобы вернуться в меню…' _
}

fail() {
    printf '%sОшибка:%s %s\n' "$RED" "$RESET" "$*" >&2
    return 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "не найдена команда '$1'"
}

version() {
    local value
    IFS= read -r value < "${PROJECT_ROOT}/VERSION.txt" || return 1
    if [[ ! "$value" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
        fail "VERSION.txt содержит некорректную версию: ${value}"
        return 1
    fi
    printf '%s\n' "$value"
}

package_version() {
    local value
    value="$(version)" || return 1
    printf '%s\n' "${value//-/_}"
}

current_package() {
    local pkgver
    pkgver="$(package_version)" || return 1
    local -a packages=()
    shopt -s nullglob
    packages=("${DIST_DIR}/isora-${pkgver}-1-"*.pkg.tar.zst)
    shopt -u nullglob
    if ((${#packages[@]} != 1)); then
        fail "для версии $(version) нужен ровно один пакет в ${DIST_DIR}; сначала выберите пункт 1"
        return 1
    fi
    printf '%s\n' "${packages[0]}"
}

build_arch_package() {
    [[ -f /etc/arch-release ]] || {
        fail 'сборка pacman-пакета поддерживается только на Arch Linux'
        return 1
    }
    require_command makepkg || return 1
    require_command sha256sum || return 1
    require_command bsdtar || return 1
    require_command pacman || return 1

    local app_version pkgver source_dir work_dir archive checksum package source_commit package_checksum
    app_version="$(version)" || return 1
    pkgver="${app_version//-/_}"
    source_dir="Isora-${app_version}"
    work_dir="${DIST_DIR}/.makepkg"
    archive="${work_dir}/${source_dir}.tar.gz"

    printf '%sСобираю Isora %s для Arch Linux…%s\n' "$BLUE" "$app_version" "$RESET"
    mkdir -p "$DIST_DIR" || return 1
    rm -rf -- "$work_dir"
    mkdir -p "$work_dir" || return 1

    tar --create --gzip --file "$archive" \
        --exclude='./.git' \
        --exclude='./build' \
        --exclude='./dist' \
        --transform "s#^\.#${source_dir}#" \
        -C "$PROJECT_ROOT" . || return 1

    cp -- "${PROJECT_ROOT}/packaging/arch/PKGBUILD" "$work_dir/PKGBUILD" || return 1
    cp -- "${PROJECT_ROOT}/packaging/arch/isora.install" "$work_dir/isora.install" || return 1
    checksum="$(sha256sum "$archive" | awk '{print $1}')" || return 1
    sed -i \
        -e "s/^pkgver=.*/pkgver=${pkgver}/" \
        -e 's/^pkgrel=.*/pkgrel=1/' \
        -e "s|^source=.*|source=(\"${source_dir}.tar.gz\")|" \
        -e "s/^sha256sums=.*/sha256sums=('${checksum}')/" \
        "$work_dir/PKGBUILD" || return 1

    (
        cd "$work_dir" || exit 1
        makepkg --syncdeps --needed --cleanbuild --force --noconfirm
    ) || return 1

    package="$(find "$work_dir" -maxdepth 1 -type f -name "isora-${pkgver}-1-*.pkg.tar.zst" \
        ! -name '*-debug-*' -print -quit)"
    [[ -n "$package" ]] || {
        fail 'makepkg завершился без ожидаемого пакета'
        return 1
    }
    pacman -Qp "$package" >/dev/null || return 1
    bsdtar -tf "$package" | grep -qx 'usr/bin/isora' || {
        fail 'в пакете нет /usr/bin/isora'
        return 1
    }
    bsdtar -tf "$package" | grep -qx 'usr/share/applications/io.github.ll_host.Isora.desktop' || {
        fail 'в пакете нет desktop entry Isora'
        return 1
    }

    find "$DIST_DIR" -maxdepth 1 -type f -name 'isora-*.pkg.tar.zst' -delete
    cp -- "$package" "$DIST_DIR/" || return 1
    package="${DIST_DIR}/$(basename -- "$package")"
    source_commit='dirty'
    if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
        [[ -z "$(git -C "$PROJECT_ROOT" status --porcelain)" ]]; then
        source_commit="$(git -C "$PROJECT_ROOT" rev-parse HEAD)" || return 1
    fi
    package_checksum="$(sha256sum "$package" | awk '{print $1}')" || return 1
    printf 'version=%s\ncommit=%s\npackage=%s\nsha256=%s\n' \
        "$app_version" "$source_commit" "$(basename -- "$package")" "$package_checksum" \
        > "${DIST_DIR}/.package-state" || return 1
    rm -rf -- "$work_dir"

    printf '%sГотово:%s %s\n' "$GREEN" "$RESET" "$package"
    printf 'Установка: sudo pacman -U %q\n' "$package"
}

verify_package_state() {
    local package="$1"
    local state_file="${DIST_DIR}/.package-state"
    [[ -f "$state_file" ]] || {
        fail 'нет данных о сборке пакета; соберите его заново пунктом 1'
        return 1
    }

    local recorded_version recorded_commit recorded_package recorded_checksum actual_checksum
    recorded_version="$(sed -n 's/^version=//p' "$state_file")"
    recorded_commit="$(sed -n 's/^commit=//p' "$state_file")"
    recorded_package="$(sed -n 's/^package=//p' "$state_file")"
    recorded_checksum="$(sed -n 's/^sha256=//p' "$state_file")"
    actual_checksum="$(sha256sum "$package" | awk '{print $1}')" || return 1

    [[ "$recorded_version" == "$(version)" &&
       "$recorded_commit" == "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" &&
       "$recorded_package" == "$(basename -- "$package")" &&
       "$recorded_checksum" == "$actual_checksum" ]] || {
        fail 'пакет не соответствует текущему коммиту; соберите его заново пунктом 1'
        return 1
    }
}

install_arch_package() {
    require_command sudo || return 1
    require_command pacman || return 1
    local package
    package="$(current_package)" || return 1
    sudo pacman -U --needed "$package"
}

ensure_release_state() {
    require_command git || return 1
    require_command gh || return 1
    git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        fail 'каталог не является Git-репозиторием'
        return 1
    }
    [[ -z "$(git -C "$PROJECT_ROOT" status --porcelain)" ]] || {
        fail 'перед релизом закоммитьте и отправьте все изменения'
        return 1
    }

    local remote branch
    remote="$(git -C "$PROJECT_ROOT" remote get-url origin 2>/dev/null)" || return 1
    remote="${remote%.git}"
    [[ "$remote" == "https://github.com/${REPOSITORY}" || "$remote" == "git@github.com:${REPOSITORY}" ]] || {
        fail "origin должен указывать на https://github.com/${REPOSITORY}.git"
        return 1
    }
    branch="$(git -C "$PROJECT_ROOT" branch --show-current)"
    [[ "$branch" == 'main' ]] || {
        fail 'релиз разрешён только из ветки main'
        return 1
    }

    git -C "$PROJECT_ROOT" fetch --prune origin main || return 1
    [[ "$(git -C "$PROJECT_ROOT" rev-parse HEAD)" == "$(git -C "$PROJECT_ROOT" rev-parse origin/main)" ]] || {
        fail 'локальная main не совпадает с origin/main; сначала выполните commit+push или pull'
        return 1
    }
    gh auth status --hostname github.com >/dev/null 2>&1 || {
        fail 'GitHub CLI не авторизован'
        return 1
    }
}

publish_release() {
    local package app_version tag package_name answer
    package="$(current_package)" || return 1
    ensure_release_state || return 1
    verify_package_state "$package" || return 1
    app_version="$(version)" || return 1
    tag="v${app_version}"
    package_name="$(basename -- "$package")"

    printf '%sБудут удалены все прежние Releases и их теги.%s\n' "$RED" "$RESET"
    printf 'Новый релиз: %s, единственный загруженный файл: %s\n' "$tag" "$package_name"
    read -r -p 'Продолжить? [y/N]: ' answer
    [[ "$answer" == 'y' || "$answer" == 'Y' ]] || {
        printf 'Публикация отменена.\n'
        return 0
    }

    if gh release view "$tag" --repo "$REPOSITORY" >/dev/null 2>&1; then
        gh release delete "$tag" --repo "$REPOSITORY" --cleanup-tag --yes || return 1
    fi
    git -C "$PROJECT_ROOT" tag -d "$tag" >/dev/null 2>&1 || true
    if git -C "$PROJECT_ROOT" ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
        git -C "$PROJECT_ROOT" push origin ":refs/tags/${tag}" || return 1
    fi
    git -C "$PROJECT_ROOT" tag -a "$tag" -m "Isora ${app_version}" || return 1
    git -C "$PROJECT_ROOT" push origin "$tag" || return 1

    local -a create_args=(
        "$tag" "$package"
        --repo "$REPOSITORY"
        --verify-tag
        --draft
        --title "Isora ${app_version}"
        --notes "Arch Linux: sudo pacman -U ${package_name}"
    )
    if [[ "$app_version" == *-* ]]; then
        create_args+=(--prerelease)
    fi
    gh release create "${create_args[@]}" || return 1

    local -a old_tags=()
    mapfile -t old_tags < <(gh release list --repo "$REPOSITORY" --limit 1000 --json tagName --jq '.[].tagName')
    local old_tag
    for old_tag in "${old_tags[@]}"; do
        [[ "$old_tag" == "$tag" ]] && continue
        gh release delete "$old_tag" --repo "$REPOSITORY" --cleanup-tag --yes || return 1
    done

    local -a edit_args=("$tag" --repo "$REPOSITORY" --draft=false)
    if [[ "$app_version" == *-* ]]; then
        edit_args+=(--prerelease)
    else
        edit_args+=(--latest)
    fi
    gh release edit "${edit_args[@]}" || return 1

    local release_count asset_count asset_name
    release_count="$(gh release list --repo "$REPOSITORY" --limit 1000 --json tagName --jq 'length')" || return 1
    asset_count="$(gh api "repos/${REPOSITORY}/releases/tags/${tag}" --jq '.assets | length')" || return 1
    asset_name="$(gh api "repos/${REPOSITORY}/releases/tags/${tag}" --jq '.assets[0].name')" || return 1
    [[ "$release_count" == '1' && "$asset_count" == '1' && "$asset_name" == "$package_name" ]] || {
        fail 'GitHub Release создан, но итоговый набор релизов или файлов не прошёл проверку'
        return 1
    }

    printf '%sОпубликован единственный актуальный релиз:%s https://github.com/%s/releases/tag/%s\n' \
        "$GREEN" "$RESET" "$REPOSITORY" "$tag"
}

commit_and_push() {
    require_command git || return 1
    local message branch
    printf 'Текущие изменения:\n'
    git -C "$PROJECT_ROOT" status --short
    read -r -p 'Сообщение коммита: ' message
    [[ -n "${message//[[:space:]]/}" ]] || {
        fail 'сообщение коммита не может быть пустым'
        return 1
    }
    git -C "$PROJECT_ROOT" add -A || return 1
    if git -C "$PROJECT_ROOT" diff --cached --quiet; then
        fail 'нет изменений для коммита'
        return 1
    fi
    git -C "$PROJECT_ROOT" commit -m "$message" || return 1
    branch="$(git -C "$PROJECT_ROOT" branch --show-current)"
    git -C "$PROJECT_ROOT" push --set-upstream origin "$branch"
}

pull_changes() {
    require_command git || return 1
    [[ -z "$(git -C "$PROJECT_ROOT" status --porcelain)" ]] || {
        fail 'перед pull рабочее дерево должно быть чистым'
        return 1
    }
    local branch
    branch="$(git -C "$PROJECT_ROOT" branch --show-current)"
    git -C "$PROJECT_ROOT" pull --rebase --prune origin "$branch"
}

show_status() {
    printf '%sВерсия:%s %s\n' "$BOLD" "$RESET" "$(version)"
    git -C "$PROJECT_ROOT" status --short --branch
    printf '\nРелизы GitHub:\n'
    gh release list --repo "$REPOSITORY" --limit 10 2>/dev/null || printf 'Недоступно\n'
    printf '\nЛокальные пакеты:\n'
    find "$DIST_DIR" -maxdepth 1 -type f -name 'isora-*.pkg.tar.zst' -printf '%f\n' 2>/dev/null || true
}

run_action() {
    printf '\n'
    if "$@"; then
        printf '%sОперация завершена.%s\n' "$GREEN" "$RESET"
    else
        local status=$?
        printf '%sОперация не выполнена (код %d).%s\n' "$RED" "$status" "$RESET" >&2
    fi
    pause_menu
}

main() {
    cd "$PROJECT_ROOT" || exit 1
    while true; do
        clear 2>/dev/null || true
        printf '%s%sIsora — локальная разработка%s\n' "$BOLD" "$BLUE" "$RESET"
        printf '%s%s%s\n\n' "$DIM" "$PROJECT_ROOT" "$RESET"
        printf '  1. Собрать пакет для Arch Linux\n'
        printf '  2. Опубликовать пакет в GitHub Releases\n'
        printf '  3. Установить собранный пакет через pacman\n'
        printf '  4. Закоммитить все изменения и отправить в GitHub\n'
        printf '  5. Подтянуть изменения из GitHub (pull --rebase)\n'
        printf '  6. Показать состояние проекта\n'
        printf '  0. Выход\n\n'
        read -r -p 'Выберите пункт: ' choice
        case "$choice" in
            1) run_action build_arch_package ;;
            2) run_action publish_release ;;
            3) run_action install_arch_package ;;
            4) run_action commit_and_push ;;
            5) run_action pull_changes ;;
            6) run_action show_status ;;
            0) exit 0 ;;
            *) printf '%sНеизвестный пункт.%s\n' "$RED" "$RESET"; sleep 1 ;;
        esac
    done
}

main "$@"
