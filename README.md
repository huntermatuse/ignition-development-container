# Ignition Development Container for GPA Ignition 8.3.x


This repo was inspired by [bwdesigngroup/ignition-docker](https://github.com/design-group/ignition-docker) who did the original work for for the development container I have used and this repo is the spiritual successor for Ignition 8.3, where containerization of Ignition is treated as a first class citizen. 

---

### Environmental Options

this container can be used by pulling `huntermatusegpa/dev8:latest` which at the time of writing uses Ignition `8.3.0`

there are four symlink options:

| Environment Variable       | Default Value                                                      | Container File Path                                                                               | Symlink File Path                         |
| -------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| `SYMLINK_PROJECTS`         | `true`                                                             | `IGNITION_INSTALL_LOCATION/data/projects`                                                         | `/WORKING_DIRECTORY/projects`             |
| `SYMLINK_THEMES`           | `true`                                                             | `IGNITION_INSTALL_LOCATION/data/config/resources/core/com.inductiveautomation.perspective/themes` | `/WORKING_DIRECTORY/themes`               |
| `SYMLINK_INGITION_FOLDERS` | `images,tag-definition,tag-group,tag-provider,tag-type-definition` | `IGNITION_INSTALL_LOCATION/data/config/resources/core/ignition/FOLDER_PATH`                       | `/WORKING_DIRECTORY/ignition/FOLDER_PATH` |
| `ADDITIONAL_DATA_FOLDERS`  |                                                                    |                                                                                                   |                                           |

Other Environmental Options:

|Environment Variable|Value|
|---|---|
|`WORKING_DIRECTORY`|`/workdir`|
|`ACCEPT_IGNITION_EULA`|`Y`|
|`GATEWAY_ADMIN_USERNAME`|`admin`|
|`GATEWAY_ADMIN_PASSWORD`|`password`|
|`IGNITION_EDITION`|`standard`|
|`GATEWAY_MODULES_ENABLED`|`com.inductiveautomation.alarm-notification,com.inductiveautomation.opcua.drivers.ablegacy,com.inductiveautomation.opcua.drivers.logix,com.inductiveautomation.opcua,com.inductiveautomation.perspective,com.inductiveautomation.reporting,com.inductiveautomation.historian,com.inductiveautomation.webdev`|
|`IGNITION_UID`|`1000`|
|`IGNITION_GID`|`1000`|
|`DEVELOPER_MODE`|`N`|
|`GATEWAY_PUBLIC_ADDRESS`|`localhost`|
|`GATEWAY_PUBLIC_HTTP_PORT`|`8088`|
|`GATEWAY_PUBLIC_HTTPS_PORT`|`8043`|
|`DISABLE_QUICKSTART`|`true`|


### Third Party Modules

This functionality remains the same from the design-group, however they are mapped to the modl folder now so you will need to use the java dns name to have the modules enabled at the start of the container. 

Any additional modules outside of the native ignition ones that want to be added can be mapped into the `/modules` folder in the container. This is done by adding the following to the `volumes` section of the `docker-compose.yml` file:

```yaml
environment:
	ACCEPT_MODULE_LICENSES: com.yourmodlhere.name
	ACCEPT_MODULE_CERTS: com.yourmodlhere.name
	GATEWAY_MODULES_ENABLED: com.yourmodlhere.name + the ignition modules
volumes:
	- ./some-modules:/modules

```


### Deploying

My typical docker-compose.yml file paired with a .env file to keep the compose file a bit cleaner

```YAML
# hunter matuse // October 2025
---

x-default-logging: &default-logging
  logging:
    options:
      max-size: '100m'
      max-file: '5'
    driver: json-file

services:
  core-gateway:
    <<: [ *default-logging ]
    image: huntermatusegpa/dev8:latest
    ports:
      - 19080:8088
      - 19088:8043
    environment:
      - .env
    volumes:
      - ./ignition-files/projects:/workdir/projects
      - ./ignition-files/themes:/workdir/themes
      # tags, images, gateway settings, configs from ARG SYMLINK_IGNITION_FOLDERS
      - ./ignition-files/ignition:/workdir/ignition
      - ./ignition-files/modules:/modules

```

```env
# Time zone
TZ=America/NewYork

# Gateway credentials
GATEWAY_ADMIN_PASSWORD=${GATEWAY_PASSWORD:-password}

# Developer mode
DEVELOPER_MODE=Y

# Module licenses and certificates
ACCEPT_MODULE_LICENSES=com.mussonindustrial.embr.charts,com.mussonindustrial.embr.periscope,com.automation_pros.simaids

ACCEPT_MODULE_CERTS=com.mussonindustrial.embr.charts,com.mussonindustrial.embr.periscope,com.automation_pros.simaids

# Enabled Ignition modules
GATEWAY_MODULES_ENABLED=com.inductiveautomation.alarm-notification,com.inductiveautomation.eam,com.inductiveautomation.eventstream,com.inductiveautomation.connectors.kafka,com.inductiveautomation.opcua.drivers.logix,com.inductiveautomation.opcua,com.inductiveautomation.perspective,com.inductiveautomation.reporting,com.inductiveautomation.sfc,com.inductiveautomation.sqlbridge,com.inductiveautomation.historian.sql,com.inductiveautomation.symbol-factory,com.inductiveautomation.webdev,com.inductiveautomation.historian,com.mussonindustrial.embr.charts,com.mussonindustrial.embr.periscope,com.automation_pros.simaids

```

### Building a pushing a specific version

1. Open a terminal or command prompt on your host machine.
2. Navigate to the directory containing both `Dockerfile` and the `docker-bake.hcl`
3. Run `docker buildx bake --file ./docker-bake.hcl <build-target> --push`
