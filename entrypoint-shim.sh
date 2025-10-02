#!/usr/bin/env bash

# shellcheck source=/usr/local/bin/script-utils.sh
# shellcheck disable=SC1091
source /usr/local/bin/script-utils.sh

# Enable error handling
trap handle_error ERR

args=("$@")

# Declare a map of wrapper arguments
declare -A wrapper_args_map=(
    ["-Dignition.projects.scanFrequency"]=${PROJECT_SCAN_FREQUENCY:-10}
)

# Declare a map of JVM arguments
declare -A jvm_args_map=()

main() {
    log_info "Starting Ignition gateway initialization"

    # Create the data folder for Ignition
    mkdir -p "${IGNITION_INSTALL_LOCATION}/data"
    log_info "Created data folder: ${IGNITION_INSTALL_LOCATION}/data"

    if [ "$SYMLINK_PROJECTS" = "true" ] || [ "$SYMLINK_THEMES" = "true" ] || [ -n "$SYMLINK_IGNITION_FOLDERS" ]; then
        mkdir -p "${WORKING_DIRECTORY}"
        log_info "Created working directory: ${WORKING_DIRECTORY}"
        [ "$SYMLINK_PROJECTS" = "true" ] && symlink_projects
        [ -n "$ADDITIONAL_DATA_FOLDERS" ] && setup_additional_folder_symlinks "$ADDITIONAL_DATA_FOLDERS"
    fi

    # Copy and register modules
    if [ -d "/modules" ]; then
        copy_modules_to_user_lib
    fi

    # Developer mode args
    [ "$DEVELOPER_MODE" = "Y" ] && add_developer_mode_args

    # Create dedicated user
    create_dedicated_user

    # Prepare launch arguments
    prepare_launch_args

    # Add post-startup hook for resource symlinks
    setup_post_startup_symlinks

    # Launch Ignition
    entrypoint "${args[@]}"
}

################################################################################
# Setup a dedicated user based off the UID and GID provided
################################################################################
create_dedicated_user() {
    groupmod -g "${IGNITION_GID}" ignition
    usermod -u "${IGNITION_UID}" ignition
    chown -R "${IGNITION_UID}":"${IGNITION_GID}" /usr/local/bin/
    [ -d "${WORKING_DIRECTORY}" ] && chown -R "${IGNITION_UID}":"${IGNITION_GID}" "${WORKING_DIRECTORY}"
}

################################################################################
# Create the projects directory and symlink it
################################################################################
symlink_projects() {
    local target_dir="${IGNITION_INSTALL_LOCATION}/data/projects"
    local source_dir="${WORKING_DIRECTORY}/projects"
    
    if [ ! -L "$target_dir" ]; then
        mkdir -p "$source_dir"
        ln -s "$source_dir" "$target_dir"
        log_info "Created symlink: $target_dir -> $source_dir"
    fi
}

################################################################################
# Setup post-startup symlinks for resources that need core to exist first
################################################################################
setup_post_startup_symlinks() {
    if [ "$SYMLINK_THEMES" = "true" ] || [ -n "$SYMLINK_IGNITION_FOLDERS" ]; then
        (
            log_info "Waiting for Ignition to create core resource structure..."
            max_wait=120
            wait_time=0
            
            while [ $wait_time -lt $max_wait ]; do
                if [ -d "${IGNITION_INSTALL_LOCATION}/data/config/resources/core" ]; then
                    log_info "Core resource structure detected, creating resource symlinks..."
                    sleep 2

                    [ "$SYMLINK_THEMES" = "true" ] && create_themes_symlink
                    [ -n "$SYMLINK_IGNITION_FOLDERS" ] && create_ignition_folder_symlinks

                    chown -R "${IGNITION_UID}":"${IGNITION_GID}" "${WORKING_DIRECTORY}"
                    
                    log_info "Resource symlinks created successfully"
                    break
                fi
                sleep 1
                wait_time=$((wait_time + 1))
            done
            
            if [ $wait_time -ge $max_wait ]; then
                log_error "Timeout waiting for core resource structure"
            fi
        ) &
    fi
}

################################################################################
# Create the themes directory and symlink it
################################################################################
create_themes_symlink() {
    local target_dir="${IGNITION_INSTALL_LOCATION}/data/config/resources/core/com.inductiveautomation.perspective/themes"
    local source_dir="${WORKING_DIRECTORY}/themes"
    
    if [ ! -L "$target_dir" ] && [ ! -d "$target_dir" ]; then
        mkdir -p "$(dirname "$target_dir")"
        mkdir -p "$source_dir"
        ln -s "$source_dir" "$target_dir"
        log_info "Created symlink: $target_dir -> $source_dir"
    elif [ -d "$target_dir" ] && [ ! -L "$target_dir" ]; then
        mkdir -p "$source_dir"
        if [ "$(ls -A "$target_dir")" ]; then
            mv "$target_dir"/* "$source_dir"/ 2>/dev/null || true
        fi
        rm -rf "$target_dir"
        ln -s "$source_dir" "$target_dir"
        log_info "Migrated and created symlink: $target_dir -> $source_dir"
    fi
}

################################################################################
# Create symlinks for ignition core folders
################################################################################
create_ignition_folder_symlinks() {
    local base_target_dir="${IGNITION_INSTALL_LOCATION}/data/config/resources/core/ignition"
    local base_source_dir="${WORKING_DIRECTORY}/ignition"

    mkdir -p "$base_source_dir"
    
    IFS=',' read -ra FOLDERS <<< "${SYMLINK_IGNITION_FOLDERS}"
    
    for folder in "${FOLDERS[@]}"; do
        folder=$(echo "$folder" | xargs)
        
        if [ -z "$folder" ]; then
            continue
        fi
        
        local target_dir="${base_target_dir}/${folder}"
        local source_dir="${base_source_dir}/${folder}"
        
        if [ ! -L "$target_dir" ] && [ ! -d "$target_dir" ]; then
            mkdir -p "$source_dir"
            ln -s "$source_dir" "$target_dir"
            log_info "Created symlink: $target_dir -> $source_dir"
        elif [ -d "$target_dir" ] && [ ! -L "$target_dir" ]; then
            mkdir -p "$source_dir"
            if [ "$(ls -A "$target_dir")" ]; then
                log_info "Migrating existing content from $target_dir to $source_dir"
                mv "$target_dir"/* "$source_dir"/ 2>/dev/null || true
            fi
            rm -rf "$target_dir"
            ln -s "$source_dir" "$target_dir"
            log_info "Migrated and created symlink: $target_dir -> $source_dir"
        else
            log_info "Symlink already exists: $target_dir"
        fi
    done
}

################################################################################
# Setup additional folder symlinks
################################################################################
setup_additional_folder_symlinks() {
    local ADDITIONAL_FOLDERS="${1}"
    IFS=',' read -ra ADDITIONAL_FOLDERS_ARRAY <<< "${ADDITIONAL_FOLDERS}"
    for ADDITIONAL_FOLDER in "${ADDITIONAL_FOLDERS_ARRAY[@]}"; do
        if [ ! -L "${IGNITION_INSTALL_LOCATION}/data/${ADDITIONAL_FOLDER}" ]; then
            log_info "Creating symlink for ${ADDITIONAL_FOLDER}"
            ln -s "${WORKING_DIRECTORY}/${ADDITIONAL_FOLDER}" "${IGNITION_INSTALL_LOCATION}/data/"
            log_info "Creating workdir folder for ${ADDITIONAL_FOLDER}"
            mkdir -p "${WORKING_DIRECTORY}/${ADDITIONAL_FOLDER}"
        fi
    done
}

################################################################################
# Copy and register modules
################################################################################
copy_modules_to_user_lib() {
    if ! ls /modules/*.modl 1>/dev/null 2>&1; then
        log_info "No additional modules found in /modules"
        return
    fi

    cp -r /modules/*.modl "${IGNITION_INSTALL_LOCATION}/user-lib/modules/"
}

################################################################################
# Enable developer mode args
################################################################################
add_developer_mode_args() {
    wrapper_args_map+=(["-Dia.developer.moduleupload"]="true")
    wrapper_args_map+=(["-Dignition.allowunsignedmodules"]="true")
}

################################################################################
# Prepare launch arguments
################################################################################
prepare_launch_args() {
    local wrapper_args=()
    for key in "${!wrapper_args_map[@]}"; do
        wrapper_args+=("${key}=${wrapper_args_map[${key}]}")
        log_info "Collected wrapper arg: ${key}=${wrapper_args_map[${key}]}"
    done

    local jvm_args=()
    for key in "${!jvm_args_map[@]}"; do
        jvm_args+=("${key}" "${jvm_args_map[${key}]}")
        log_info "Collected JVM arg: ${key} ${jvm_args_map[${key}]}"
    done

    if [[ " ${args[*]} " =~ " -- " ]]; then
        args=("${args[@]/#-- /-- ${jvm_args[*]} }")
    else
        args+=("${jvm_args[@]}")
    fi

    [[ ! " ${args[*]} " =~ " -- " ]] && args+=("--")
    args+=("${wrapper_args[@]}")
}

################################################################################
# Execute the entrypoint
################################################################################
entrypoint() {
    if [ ! -e /usr/local/bin/docker-entrypoint.sh ]; then
        mv docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
    fi

    log_info "Launching Ignition with args: $*"
    exec docker-entrypoint.sh "$@"
}

main "${args[@]}"