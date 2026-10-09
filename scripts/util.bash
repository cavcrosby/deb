#
#
# Library of shared utility code for scripts.

# constants
PROGNAME="$(basename "$0")"
readonly PROGNAME

is_ge_version() {
    local version1="${1#v}"
    local version2="${2#v}"
    shift 2

    # uniq handles equal versions
    ! printf \
        "%s\n%s\n" \
        "${version1}" \
        "${version2}" \
        | sort --version-sort \
        | uniq --unique \
        | head --lines 1 \
        | grep --quiet "${version1}"
}

checkout() {
    local src="$1"
    local version="$2"
    local repo_url="$3"
    local cache_dir_path="$4"
    shift 4

    mkdir --parents "${cache_dir_path}"
    destdir="${cache_dir_path}/${src}-${version#v}"
    if ! [ -d "${destdir}" ]; then
        git clone --branch "${version}" "${repo_url}" "${destdir}"
        cp --recursive "./src/${src}" "${destdir}/debian"
        (
            cd "${destdir}" || return 1
            debchange \
                --create \
                --package "${src}" \
                --newversion "${version#v}-1" \
                --distribution "unstable" \
                "Stub changelog entry"
        )
    else
        cp --recursive --no-target-directory "./src/${src}" "${destdir}/debian"
    fi

    printf "%s\n" "${destdir}"
}

setup() {
    if ! [ "${container_id}" ]; then
        printf \
            "%s: %s\n" \
            "${PROGNAME}" \
            "the create_container function must be ran first" \
            >&2

        exit 1
    fi

    docker container cp \
        "./scripts/setup" \
        "debian-${container_src}:${container_setup_path}"

    docker container exec \
        --workdir "${container_setup_path}" \
        "debian-${container_src}" \
        "./setup"

    docker container exec \
        --workdir "${container_setup_path}" \
        "debian-${container_src}" \
        "apt-get" \
        "install" \
        "--assume-yes" \
        "--no-install-recommends" \
        "./${container_src}-build-deps_${container_setup_version#v}-1_all.deb"
}

create_container() {
    local src="$1"
    local cache_dir_path="$2"
    shift 2

    # addition of mindepth option prevents output containing dir itself
    container_setup_version="$(\
        find "${cache_dir_path}" \
            -mindepth 1 \
            -maxdepth 1 \
            -exec basename "{}" ";" \
        | sort --version-sort \
        | head --lines 1 \
        | sed "s/${src}-//" \
    )"

    container_src="${src}"
    container_setup_path="/build/sources/${src}-${container_setup_version#v}"
    cp \
        "./src/${src}/control" \
        "${cache_dir_path}/${src}-${container_setup_version#v}/debian"

    container_id="$(\
        docker container ls \
            --quiet \
            --filter name="^debian-${src}$" \
    )"

    if ! [ "${container_id}" ]; then
        container_id="$(docker container run \
            --detach \
            --tty \
            --name "debian-${src}" \
            --mount "type=bind,src=${PWD}/..,dst=/build" \
            --mount "type=bind,src=${cache_dir_path},dst=/build/sources" \
            --workdir "/build/sources" \
            "debian:unstable" \
        )"
    fi
}

exec_container() {
    if ! [ "${container_id}" ]; then
        printf \
            "%s: %s\n" \
            "${PROGNAME}" \
            "the create_container function must be ran first" \
            >&2

        exit 1
    fi

    docker container exec "${container_id}" "$@"
}

exec_build_pkgs_container() {
    local version="$1"
    local cache_dir_path="$2"
    shift 2

    if ! [ "${container_id}" ]; then
        printf \
            "%s: %s\n" \
            "${PROGNAME}" \
            "the create_container function must be ran first" \
            >&2

        exit 1
    fi

    docker container exec \
        --workdir "/build/sources/${container_src}-${version#v}" \
        --user "$(id --user)" \
        "${container_id}" \
        "debuild" \
        "--unsigned-source" \
        "--unsigned-buildinfo" \
        "--unsigned-changes" \
        "--build=binary"

    mv "${cache_dir_path}"/*.build ".."
    mv "${cache_dir_path}"/*.buildinfo ".."
    mv "${cache_dir_path}"/*.changes ".."
    mv "${cache_dir_path}"/*.deb ".."
}

remove_container() {
    if ! [ "${container_id}" ]; then
        printf \
            "%s: %s\n" \
            "${PROGNAME}" \
            "the create_container function must be ran first" \
            >&2

        exit 1
    fi

    docker container stop "${container_id}"
    docker container rm "${container_id}"
}

if ! [ "$(command -v docker)" ]; then
    printf "%s: %s\n" "${PROGNAME}" "docker cannot be found in the PATH!" >&2
    exit 1
fi

if ! [ "$(command -v git)" ]; then
    printf "%s: %s\n" "${PROGNAME}" "git cannot be found in the PATH!" >&2
    exit 1
fi

if ! [ "$(command -v debchange)" ]; then
    printf "%s: %s\n" "${PROGNAME}" "debchange cannot be found in the PATH!" >&2
    exit 1
fi
