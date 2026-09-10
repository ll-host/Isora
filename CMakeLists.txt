cmake_minimum_required(VERSION 3.24)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION.txt" ISORA_VERSION_STRING LIMIT_COUNT 1)
string(STRIP "${ISORA_VERSION_STRING}" ISORA_VERSION_STRING)
if(NOT ISORA_VERSION_STRING MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)(-[0-9A-Za-z.-]+)?$")
    message(FATAL_ERROR "VERSION.txt must contain a SemVer value, got: ${ISORA_VERSION_STRING}")
endif()

project(Isora VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}" LANGUAGES CXX)

include(CTest)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Concurrent Gui Qml Quick QuickControls2 Network Xml)
if(NOT WIN32)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(LIBVIRT REQUIRED IMPORTED_TARGET libvirt)
endif()

qt_standard_project_setup(REQUIRES 6.8)

set(ISORA_BACKEND_SOURCE src/core/LibvirtManager.cpp)
if(WIN32)
    set(ISORA_BACKEND_SOURCE src/core/LibvirtManagerWindows.cpp)
endif()

add_library(isora-core STATIC
    src/core/AppController.cpp
    src/core/AppController.h
    src/core/AppearanceController.cpp
    src/core/AppearanceController.h
    src/core/DomainSafetyPolicy.cpp
    src/core/DomainSafetyPolicy.h
    src/core/IsoLibrary.cpp
    src/core/IsoLibrary.h
    ${ISORA_BACKEND_SOURCE}
    src/core/LibvirtManager.h
    src/core/RenderDevice.cpp
    src/core/RenderDevice.h
    src/core/ReleaseVersion.cpp
    src/core/ReleaseVersion.h
    src/core/UpdateChecker.cpp
    src/core/UpdateChecker.h
)

target_include_directories(isora-core PUBLIC src)
target_link_libraries(isora-core PUBLIC
    Qt6::Core
    Qt6::Concurrent
    Qt6::Gui
    Qt6::Network
    Qt6::Xml
)
if(NOT WIN32)
    target_link_libraries(isora-core PUBLIC PkgConfig::LIBVIRT)
else()
    target_link_libraries(isora-core PUBLIC dxgi propsys shell32)
endif()

qt_add_executable(isora WIN32 src/main.cpp)
qt_add_executable(isoractl src/cli/main.cpp)

set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(isora
    URI Isora
    VERSION 1.0
    QML_FILES
        qml/Theme.qml
        qml/Main.qml
        qml/components/ActionButton.qml
        qml/components/AppCheckBox.qml
        qml/components/AppProgress.qml
        qml/components/AppSpinBox.qml
        qml/components/AppSwitch.qml
        qml/components/AppTextField.qml
        qml/components/AppToolTip.qml
        qml/components/EmptyState.qml
        qml/components/NavigationItem.qml
        qml/components/PageHeader.qml
        qml/components/StatusBadge.qml
        qml/components/Surface.qml
        qml/pages/DiagnosticsPage.qml
        qml/pages/DisksPage.qml
        qml/pages/ImagesPage.qml
        qml/pages/MachineOverview.qml
        qml/pages/MachinesPage.qml
        qml/pages/SettingsPage.qml
    RESOURCES
        qml/assets/icons/activity.svg
        qml/assets/icons/app.svg
        qml/assets/icons/backup.svg
        qml/assets/icons/disc.svg
        qml/assets/icons/drive.svg
        qml/assets/icons/monitor.svg
        qml/assets/icons/more.svg
        qml/assets/icons/play.svg
        qml/assets/icons/plus.svg
        qml/assets/icons/refresh.svg
        qml/assets/icons/settings.svg
        qml/assets/icons/shield.svg
        qml/assets/icons/snapshot.svg
        qml/assets/icons/sun.svg
        qml/assets/icons/trash.svg
        qml/assets/icons/moon.svg
)

target_compile_definitions(isora PRIVATE
    ISORA_VERSION="${ISORA_VERSION_STRING}"
)
target_compile_definitions(isoractl PRIVATE ISORA_VERSION="${ISORA_VERSION_STRING}")
target_link_libraries(isora PRIVATE
    isora-core
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)
target_link_libraries(isoractl PRIVATE isora-core Qt6::Core)

if(WIN32)
    set_target_properties(isora PROPERTIES OUTPUT_NAME Isora)
    set_target_properties(isoractl PROPERTIES OUTPUT_NAME IsoraCLI)
else()
    set_target_properties(isora PROPERTIES OUTPUT_NAME isora)
    set_target_properties(isoractl PROPERTIES OUTPUT_NAME isoractl)
endif()
install(TARGETS isora isoractl RUNTIME DESTINATION bin)
if(NOT WIN32)
    install(FILES packaging/io.github.ll_host.Isora.desktop
            DESTINATION share/applications
            RENAME io.github.ll_host.Isora.desktop)
    install(FILES packaging/io.github.ll_host.Isora.svg
            DESTINATION share/icons/hicolor/scalable/apps
            RENAME io.github.ll_host.Isora.svg)
endif()

if(WIN32)
    set(ISORA_DEPLOY_RUNTIME_DEFAULT ON)
else()
    set(ISORA_DEPLOY_RUNTIME_DEFAULT OFF)
endif()
option(ISORA_DEPLOY_RUNTIME "Bundle the Qt runtime into install/package output" ${ISORA_DEPLOY_RUNTIME_DEFAULT})
if(ISORA_DEPLOY_RUNTIME)
    qt_generate_deploy_qml_app_script(
        TARGET isora
        OUTPUT_SCRIPT isora_deploy_script
        NO_UNSUPPORTED_PLATFORM_ERROR
    )
    install(SCRIPT ${isora_deploy_script})
endif()
if(BUILD_TESTING)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Test)
    qt_add_executable(isora-version-tests
        tests/ReleaseVersionTest.cpp
        src/core/ReleaseVersion.cpp
        src/core/ReleaseVersion.h
    )
    target_include_directories(isora-version-tests PRIVATE src)
    target_link_libraries(isora-version-tests PRIVATE Qt6::Core Qt6::Test)
    add_test(NAME release-version COMMAND isora-version-tests)

    qt_add_executable(isora-safety-tests
        tests/DomainSafetyPolicyTest.cpp
        src/core/DomainSafetyPolicy.cpp
        src/core/DomainSafetyPolicy.h
        src/core/RenderDevice.cpp
        src/core/RenderDevice.h
    )
    target_include_directories(isora-safety-tests PRIVATE src)
    target_link_libraries(isora-safety-tests PRIVATE Qt6::Core Qt6::Test Qt6::Xml)
    if(WIN32)
        target_link_libraries(isora-safety-tests PRIVATE dxgi)
    endif()
    add_test(NAME domain-safety COMMAND isora-safety-tests)

    if(NOT WIN32)
        qt_add_executable(isora-async-tests
            tests/AppControllerAsyncTest.cpp
        )
        target_include_directories(isora-async-tests PRIVATE src)
        target_link_libraries(isora-async-tests PRIVATE isora-core Qt6::Core Qt6::Test)
        add_test(NAME app-controller-async COMMAND isora-async-tests)

        qt_add_executable(isora-libvirt-tests
            tests/LibvirtManagerIntegrationTest.cpp
        )
        target_include_directories(isora-libvirt-tests PRIVATE src)
        target_link_libraries(isora-libvirt-tests PRIVATE isora-core Qt6::Core Qt6::Test)
        add_test(NAME libvirt-integration COMMAND isora-libvirt-tests)
    endif()
endif()

if(WIN32)
    set(CPACK_PACKAGE_NAME "Isora")
    set(CPACK_PACKAGE_VENDOR "Isora")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Local QEMU virtual machine manager")
    set(CPACK_PACKAGE_VERSION "${ISORA_VERSION_STRING}")
    set(CPACK_PACKAGE_FILE_NAME "Isora-${ISORA_VERSION_STRING}-Windows-${CMAKE_SYSTEM_PROCESSOR}")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "Isora")
    set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
    set(CPACK_VERBATIM_VARIABLES YES)
    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_NSIS_DISPLAY_NAME "Isora")
    set(CPACK_NSIS_PACKAGE_NAME "Isora")
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    set(CPACK_NSIS_MANIFEST_DPI_AWARE ON)
    set(CPACK_NSIS_MODIFY_PATH ON)
    set(CPACK_NSIS_MUI_FINISHPAGE_RUN "bin\\Isora.exe")
    set(CPACK_NSIS_MENU_LINKS "bin/Isora.exe" "Isora")
    include(CPack)
endif()
