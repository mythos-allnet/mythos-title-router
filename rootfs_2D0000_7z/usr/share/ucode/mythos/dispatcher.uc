'use strict';

import { popen } from 'fs';
import { isnan } from 'math';

import { cursor } from 'uci';

import { wrap_uci_ubus } from 'mythos.uci_wrapper';

function shellquote(s) {
	return `'${replace(s ?? '', "'", "'\\''")}'`;
}

function command(cmd) {
	return trim(popen(cmd)?.read?.('all'));
}

function _wireguard_public_key(private_key) {
	const public_key = command(`echo ${shellquote(private_key)} | wg pubkey 2>/dev/null`);

	return rtrim(public_key, '\n');
}

/*
function wifi_scan()
	local iwinfo = require("iwinfo")
	local uci = require("luci.model.uci")
	local sys = require("luci.sys")

	-- Turn on WiFi radio if not already on
	local x = uci.cursor()
	local name = x:get_first("wireless", "wifi-device")
	if x:get("wireless", name, "disabled") == "1" then
		x:set("wireless", name, "disabled", "0")
		x:commit("wireless")
		sys.call("wifi")
	end

	-- Try to find radio and scan for networks
	local ifname = "radio0"
	local witype = iwinfo.type(ifname)
	local result = {}

	if witype then
		result.status = 0
		local iw = iwinfo[witype]
		local scanlist = iw.scanlist(ifname)
		result.list = scanlist
	else
		result.status = 1
		result.list = {}
	end

	return result
end
*/

/*
function wifi_off() {
	const uci = cursor();

	// Disable all Wi-Fi radios
	uci.foreach('wireless', 'wifi-device', function(s) {
		uci.set('wireless', s['.name'], 'disabled', '1');
	});

	uci.commit('wireless');

	system('wifi >/dev/null 2>&1'); // unexpectedly needed to apply
	system('/etc/init.d/network restart >/dev/null 2>&1');

	return {
		status: 0,
	};
}

// TODO: This needs a rewrite to handle multiple interfaces
function wifi_set(netname, netpass, netenc) {
	const uci = cursor();

	// Turn on Enable WiFi radio
	const wifi_device_name = uci.get_first('wireless', 'wifi-device');
	uci.set('wireless', wifi_device_name, 'disabled', '0');

	if (netname != null) {
		let iface_name = uci.get_first('wireless', 'wifi-iface');

		if (iface_name != null) {
			uci.delete('wireless', iface_name);
		}

		uci.section('wireless', 'wifi-iface', iface_name, {
			ssid: netname,
			device: 'radio0',
			mode: 'sta',
			network: 'wwan',
		});

		if (netenc != null) {
			uci.set('wireless', iface_name, 'encryption', netenc);

			if (netpass != null) {
				uci.set('wireless', iface_name, 'key', netpass);
			}
		}
	}

	uci.commit('wireless');

	system('wifi >/dev/null 2>&1'); // unexpectedly needed to apply
	system('/etc/init.d/network restart >/dev/null 2>&1');

	return {
		status: 0,
	};
}
*/

function vpn_set(
	network,
	vpn_ip_address_octet_3,
	vpn_ip_address_octet_4,
	vpn_private_key,
	lan_ip_address_subnet,
	lan_ip_address_subnet_custom
) {
	let vpn_ip_address_base = '';
	let vpn_endpoint_public_key = '';
	let vpn_endpoint_allowed_ips = [];
	let vpn_endpoint_host = '';
	let vpn_endpoint_port = 0;

	if (network == 'mythos') {
		vpn_ip_address_base = '172.18.';
		vpn_endpoint_public_key = '7JQlXf9CpKC6ZcxU+MS2/QP3A72dL9bQloIqodoQGGw=';
		vpn_endpoint_allowed_ips = [
			'172.18.0.1/32',
		];
		vpn_endpoint_host = 'gatewaaai.mythos.fun';
		vpn_endpoint_port = 30998;
	} else if (network == 'evoker') {
		vpn_ip_address_base = '172.19.';
		vpn_endpoint_public_key = 'ajhh780+4LFJ8Ra/eegseaNWQV0rNsvQd3IvWxO33XA=';
		vpn_endpoint_allowed_ips = [
			'172.19.0.1/32',
		];
		vpn_endpoint_host = 'gatewaaai.evoker.fun';
		vpn_endpoint_port = 30998;
	} else {
		return { status: 1, msg: 'Invalid network selected' };
	}

	if (vpn_ip_address_octet_3 == null || vpn_ip_address_octet_4 == null) {
		return { status: 2, msg: 'VPN IP address suffix is not defined' };
	}
	if (vpn_private_key == null) {
		return { status: 3, msg: 'VPN private key is not defined' };
	}
	if (length(vpn_private_key) == 0) {
		return { status: 4, msg: 'Invalid VPN private key provided' };
	}

	// Use the custom field if it is set as such
	if ((lan_ip_address_subnet == null || lan_ip_address_subnet == 'custom') &&
		lan_ip_address_subnet_custom != null)
	{
		lan_ip_address_subnet = lan_ip_address_subnet_custom;
	}

	if (lan_ip_address_subnet == null) {
		return { status: 5, msg: 'LAN IP address subnet is not defined' };
	}

	vpn_ip_address_octet_3 = int(vpn_ip_address_octet_3);
	vpn_ip_address_octet_4 = int(vpn_ip_address_octet_4);
	lan_ip_address_subnet = int(lan_ip_address_subnet);

	if (isnan(vpn_ip_address_octet_3) || isnan(vpn_ip_address_octet_4)) {
		return { status: 6, msg: 'VPN IP address suffix is not a number' };
	}
	if (isnan(lan_ip_address_subnet)) {
		return { status: 7, msg: 'LAN IP address subnet is not a number' };
	}

	// Attempt to decode the WireGuard private key as base64 to ensure it is properly encoded base64
	if (b64dec(vpn_private_key) == null) {
		return { status: 8, msg: 'Invalid VPN private key provided' };
	}

	const vpn_ip_address = `${vpn_ip_address_base}${vpn_ip_address_octet_3}.${vpn_ip_address_octet_4}`;
	const lan_ip_address = `192.168.${lan_ip_address_subnet}.254`;

	// Get public key for the given private key
	const vpn_public_key = _wireguard_public_key(vpn_private_key);
	if (length(vpn_public_key) == 0) {
		return { status: 9, msg: 'Invalid VPN private key provided' };
	}

	// Open UCI context
	const uci = wrap_uci_ubus();

	let firewall_vpn_zone_cfg_name = null;

	// Delete the old VPN interface and remove all networks from the VPN firewall zone
	uci.foreach('firewall', 'zone', function(s) {
		if (s.name == 'vpn') {
			firewall_vpn_zone_cfg_name = s['.name'];

			return false;
		}
	});
	if (firewall_vpn_zone_cfg_name != null) {
		uci.delete('firewall', firewall_vpn_zone_cfg_name, 'network');
	}
	uci.delete('network', 'wg0');
	uci.delete_all('network', 'wireguard_wg0');

	// Set the new router LAN IP address
	const old_lan_ip_addresses = [];
	const old_lan_ip_address_raw = uci.get('network', 'lan', 'ipaddr');
	if (type(old_lan_ip_address_raw) == 'array') {
		for (let old_lan_ip_address in old_lan_ip_address_raw) {
			push(old_lan_ip_addresses, split(old_lan_ip_address, '/')[0]);
		}
	} else {
		push(old_lan_ip_addresses, old_lan_ip_address_raw);
	}
	uci.set('network', 'lan', 'ipaddr', [`${lan_ip_address}/24`]);
	// Ensure the `netmask` element is removed
	uci.delete('network', 'lan', 'netmask');

	// Adjust shop router host overrides
	uci.foreach('dhcp', 'domain', function(s) {
		const name = s.name;

		if (name == 'tenporouter.loc' || name == 'bbrouter.loc') {
			uci.set('dhcp', s['.name'], 'ip', vpn_ip_address);
		}
	});

	// Adjust host overrides that point to the router LAN IP
	if (length(old_lan_ip_addresses) > 0) {
		uci.foreach('dhcp', 'domain', function(s) {
			for (let old_lan_ip_address in old_lan_ip_addresses) {
				if (s.ip == old_lan_ip_address) {
					uci.set('dhcp', s['.name'], 'ip', lan_ip_address);
				}
			}
		});
	}

	// Add the new VPN interface
	uci.section('network', 'interface', 'wg0', {
		proto: 'wireguard',
		private_key: vpn_private_key,
		addresses: [`${vpn_ip_address}/32`],
		// MTU is set low here and on the server to avoid issues with PPPoE and other
		// technologies
		mtu: 1280,
	});
	uci.section('network', 'wireguard_wg0', null, {
		description: 'Gateway',
		public_key: vpn_endpoint_public_key,
		allowed_ips: vpn_endpoint_allowed_ips,
		route_allowed_ips: '1',
		endpoint_host: vpn_endpoint_host,
		endpoint_port: vpn_endpoint_port,
		persistent_keepalive: '25',
	});
	if (firewall_vpn_zone_cfg_name != null) {
		uci.set('firewall', firewall_vpn_zone_cfg_name, 'network', ['wg0']);
	}

	// Commit UCI changes
	uci.commit('dhcp');
	uci.commit('firewall');
	uci.commit('network');

	// Refresh overridden DNS
	system('/etc/init.d/mythos_dns restart >/dev/null 2>&1');

	return {
		status: 0,
		network,
		vpn_public_key,
		vpn_ip_address,
		lan_ip_address,
	};
}

function vpn_status() {
	const uci = cursor();

	const lan_ip_address = uci.get('network', 'lan', 'ipaddr');
	const vpn_interface = uci.get_all('network', 'wg0');

	let result = {
		lan_ip_address,
		vpn_ip_address: null,
		vpn_public_key: null,
	};

	if (vpn_interface != null) {
		const vpn_ip_address = vpn_interface['addresses'][0];
		const vpn_private_key = vpn_interface['private_key'];

		const vpn_public_key = _wireguard_public_key(vpn_private_key);

		result.vpn_ip_address = vpn_ip_address;
		result.vpn_public_key = vpn_public_key;
	}

	return result;
}

function dispatch(http) {
	const cmd = http.formvalue('cmd');

	/*
	if (cmd == 'wifi_list') {
		const result = wifi_scan();

		http.status(200, 'OK');
		http.prepare_content('application/json');
		http.write_json(result);

		return;
	}

	if (cmd == 'wired') {
		const result = wifi_off();

		http.status(200, 'OK');
		http.prepare_content('application/json');
		http.write_json(result);

		return;
	}

	if (cmd == 'wireless') {
		const result = wifi_set(
			http.formvalue('ssid'),
			http.formvalue('password'),
			http.formvalue('encryption')
		);

		http.status(200, 'OK');
		http.prepare_content('application/json');
		http.write_json(result);

		return;
	}
	*/

	if (cmd == 'ver') {
		http.status(200, 'OK');
		http.prepare_content('application/json');
		http.write_json({
			ver: '2.0.0.0',
			status: 0,
		});

		return;
	}

	if (cmd == 'vpn_set') {
		const result = vpn_set(
			http.formvalue('network'),
			http.formvalue('vpn-ip-address-octet-3'),
			http.formvalue('vpn-ip-address-octet-4'),
			http.formvalue('vpn-private-key'),
			http.formvalue('lan-ip-address-subnet'),
			http.formvalue('lan-ip-address-subnet-custom')
		);

		http.status(200, 'OK');
		http.prepare_content('application/json');
		http.write_json(result);

		return;
	}

	if (cmd == 'vpn_status') {
		const result = vpn_status();

		http.status(200, 'OK');
		http.prepare_content('application/json');
		http.write_json(result);

		return;
	}

	if (cmd == 'debug') {
		http.status(200, 'OK');
		http.prepare_content('text/html');

		http.write('<h1>Headers</h1>\n');

		for (k in env.headers) {
			http.write(`<strong>${k}</strong>: ${env.headers[k]}<br>\n`);
		}

		http.write('<h1>Environment</h1>\n');

		for (k in env) {
			if (type(env[k]) == 'string') {
				http.write(`<code>${k}=${env[k]}</code><br>\n`);
			}
		}

		http.write('<h1>Parameters</h1>\n');

		// Invoking `req.formvalue` without name will return a table of all args
		const form_values = req.formvalue();

		for (k in form_values) {
			http.write(`<strong>${k}</strong>: ${form_values[k]}<br>\n`);
		}

		return;
	}
}

export default dispatch;
