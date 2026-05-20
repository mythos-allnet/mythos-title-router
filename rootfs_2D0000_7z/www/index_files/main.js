(function() {
    const apiEndpoint = "/cgi-bin/mythos/";

    const configForm = document.getElementById("config-form");
    const lanGameType = document.getElementById("lan-game-type");
    const lanIpAddressSubnetCustom = document.getElementById("lan-ip-address-subnet-custom");
    const lanIpAddressSubnetSection = document.getElementById("lan-ip-address-subnet-section");
    const network = document.getElementById("network");
    const networkStatus = document.getElementById("network-status");
    const networkStatusText = document.getElementById("network-status-text");
    const saveOutput = document.getElementById("save-output");
    const saveOutputText = document.getElementById("save-output-text");
    const submit = document.getElementById("submit");
    const usingSegaRouterKit = document.getElementById("using-sega-router-kit");
    const usingSegaRouterKitSection = document.getElementById("using-sega-router-kit-section");
    const vpnIpAddressPrefix = document.getElementById("vpn-ip-address-prefix");
    const vpnIpAddressSuffix = document.getElementById("vpn-ip-address-suffix");

    function getLanIpAddressSubnetCustom() {
        return lanIpAddressSubnetCustom.value;
    }

    function getUsingSegaRouterKit() {
        return !!usingSegaRouterKit.checked;
    }

    function getSelectedGameType() {
        for (const option of lanGameType.selectedOptions) {
            return option.textContent;
        }

        // Default to "Chunithm" if for some reason there is no selection
        return "Chunithm";
    }

    let previousGameType = getSelectedGameType();
    let previousLanIpAddressCustom = getLanIpAddressSubnetCustom();
    let previousUsingSegaRouterKitState = getUsingSegaRouterKit();

    function updateLanSection() {
        const isUsingSegaRouterKit = getUsingSegaRouterKit();

        // Disable the game type field if using the SEGA router kit
        lanGameType.disabled = isUsingSegaRouterKit;

        if (previousUsingSegaRouterKitState !== isUsingSegaRouterKit) {
            // Remove current selection to add new selection
            for (const option of lanGameType.selectedOptions) {
                option.selected = false;
            }

            if (isUsingSegaRouterKit) {
                for (const option of lanGameType.children) {
                    if (option.value === "router-kit") {
                        option.selected = true;

                        break;
                    }
                }

                // `192.168.10.0` is used for router kit use
                lanIpAddressSubnetCustom.value = "10";
            } else {
                for (const option of lanGameType.children) {
                    if (option.textContent === previousGameType) {
                        option.selected = true;

                        break;
                    }
                }

                lanIpAddressSubnetCustom.value = previousLanIpAddressCustom;
            }
        }

        // `previousGameType` might be "Custom", so do this update here after
        // the selection is updated by the router kit update code.
        const isCustom = getSelectedGameType() === "Custom";

        if (isCustom && !isUsingSegaRouterKit) {
            lanIpAddressSubnetSection.classList.remove("d-none");
        } else {
            lanIpAddressSubnetSection.classList.add("d-none");
        }

        previousUsingSegaRouterKitState = isUsingSegaRouterKit;
    }

    function adjustVpnIpAddressPrefix(value) {
        if (value === "evoker") {
            vpnIpAddressPrefix.textContent = "172.19.";
        } else if (value === "mythos") {
            vpnIpAddressPrefix.textContent = "172.18.";
        }
    }

    function updateSaveOutputText(text) {
        if (text !== null) {
            saveOutput.classList.remove("d-none");
            saveOutputText.children[0].textContent = text;
        } else {
            saveOutput.classList.add("d-none");
            saveOutputText.children[0].textContent = "";
        }
    }

    function updateNetworkStatusText(text) {
        if (text !== null) {
            networkStatus.classList.remove("d-none");
            networkStatusText.children[0].textContent = text;
        } else {
            networkStatus.classList.add("d-none");
            networkStatusText.children[0].textContent = "";
        }
    }

    function updateNetworkStatus() {
        const vpnStatusFormData = new FormData();

        vpnStatusFormData.append("cmd", "vpn_status");

        fetch(apiEndpoint, {
            method: "post",
            body: vpnStatusFormData,
        }).then((res) => {
            if (res.ok) {
                res.json()
                    .then((value) => {
                        updateNetworkStatusText(JSON.stringify(value, null, 2));
                    })
                    .catch((err) => {
                        updateNetworkStatusText(err.toString());
                    });
            } else {
                res.text()
                    .then((value) => {
                        updateNetworkStatusText(value);
                    })
                    .catch((err) => {
                        updateNetworkStatusText(err.toString());
                    });
            }
        }).catch((err) => {
            updateNetworkStatusText(err.toString());
        });
    }

    network.addEventListener("change", (event) => {
        adjustVpnIpAddressPrefix(event.target.value);
    });
    lanGameType.addEventListener("change", (event) => {
        previousGameType = getSelectedGameType();

        updateLanSection();
    });
    lanIpAddressSubnetCustom.addEventListener("change", (event) => {
        previousLanIpAddressCustom = getLanIpAddressSubnetCustom();

        updateLanSection();
    });
    usingSegaRouterKit.addEventListener("input", (event) => {
        updateLanSection();
    });

    configForm.addEventListener("submit", (event) => {
        event.preventDefault();

        // Disable the button while processing
        submit.disabled = true;

        // Clear the status view
        updateSaveOutputText(null);

        fetch(configForm.action, {
            method: "post",
            body: new FormData(configForm),
        }).then((res) => {
            submit.disabled = false;

            if (res.ok) {
                res.json()
                    .then((value) => {
                        updateSaveOutputText(JSON.stringify(value, null, 2));
                    })
                    .catch((err) => {
                        updateSaveOutputText(err.toString());
                    });
            } else {
                res.text()
                    .then((value) => {
                        updateSaveOutputText(value);
                    })
                    .catch((err) => {
                        updateSaveOutputText(err.toString());
                    });
            }

            updateNetworkStatus();
        }).catch((err) => {
            submit.disabled = false;

            updateSaveOutputText(err.toString());
            updateNetworkStatus();
        });
    });

    adjustVpnIpAddressPrefix(network.value);
    updateLanSection();
    updateNetworkStatus();
})();
