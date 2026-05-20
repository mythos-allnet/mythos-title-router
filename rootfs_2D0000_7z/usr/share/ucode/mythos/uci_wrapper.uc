'use strict';

import { connect } from 'ubus';

const UbusUciWrapperClass = {
	call: function(cmd, args) {
		// Clear previous error
		this.ubus.error();

		//printf("Calling 'uci.%s' with %J\n", cmd, args);
		const res = this.ubus.call('uci', cmd, args);
		const err = this.ubus.error(true);
		//printf("Called 'uci.%s' with %J: err: %J, res: %J\n", cmd, args, err, res);

		/*
		if (err != null) {
			printf("Call to 'uci.%s' with %J failed: %J\n", cmd, args, err);
		}
		*/

		this.error = err;

		return res ?? !this.error;
	},

	commit: function(config) {
		this.call('commit', {
			'config': config,
		});

		return this.error == null;
	},
	foreach: function(config, stype, callback) {
		if (type(callback) == 'function') {
			const rv = this.call('get', {
				'config': config,
				'type': stype,
			});

			if (type(rv) == 'object' && type(rv.values) == 'object') {
				const sections = [];
				let res = false;
				let index = 0;

				for (let key, section in rv.values) {
					section['.index'] = (section['.index'] - 1) || index;
					sections[index] = section;
					index = index + 1;
				}

				sort(sections, function(a, b) {
					return a['.index'] < b['.index'];
				});

				for (let section in sections) {
					const cont = callback(section);
					res = true;
					if (cont == false) {
						break;
					}
				}

				return res;
			} else {
				//printf('uci.foreach: No data\n');

				return false;
			}
		} else {
			//printf('uci.foreach: Invalid argument\n');

			return false;
		}
	},
	get: function(config, section, option) {
		if (section == null) {
			return null;
		} else if (type(option) == 'string' && substr(option, 0, 1) != '.') {
			const rv = this.call('get', {
				'config': config,
				'section': section,
				'option': option,
			});

			if (type(rv) == 'object') {
				return rv.value || null;
			} else if (this.error) {
				return false;
			} else {
				return null;
			}
		} else if (option == null) {
			const values = this.get_all(config, section);

			if (values != null) {
				return [values['.type'], values['.name']];
			} else {
				return null;
			}
		} else {
			//printf('uci.get: Invalid argument\n');

			return false;
		}

	},
	get_all: function(config, section) {
		const rv = this.call('get', {
			'config': config,
			'section': section,
		});

		if (type(rv) == 'object' && type(rv.values) == 'object') {
			return rv.values;
		} else if (this.error) {
			return false;
		} else {
			return null;
		}
	},
	section: function(config, stype, name, values) {
		const rv = this.call('add', {
			'config': config,
			'type': stype,
			'name': name,
			'values': values,
		});

		if (type(rv) == 'object') {
			return rv.section;
		} else if (this.error) {
			return false;
		} else {
			return null;
		}
	},
	add: function(config, stype) {
		return this.section(config, stype);
	},
	set: function(config, section, option, ...args) {
		if (length(args) == 0) {
			const sname = this.section(config, option, section);

			return !!sname;
		} else {
			this.call('set', {
				'config': config,
				'section': section,
				'values': {
					// Translated `select(1, ...)` to `args[0]`
					// This is not an exact translation and should be improved
					[option]: args[0],
				},
			});

			return this.error == null;
		}
	},
	set_list: function(config, section, option, value) {
		if (section == null || option == null) {
			return false;
		} else if (value == null || (type(value) == 'object' && length(value) == 0)) {
			return this.delete(config, section, option);
		} else if (type(value) == 'array') {
			return this.set(config, section, option, value);
		} else {
			return this.set(config, section, option, [value]);
		}
	},
	tset: function(config, section, values) {
		this.call('set', {
			'config': config,
			'section': section,
			'values': values,
		});

		return this.error == null;
	},
	delete: function(config, section, option) {
		this.call('delete', {
			'config': config,
			'section': section,
			'option': option,
		});

		return this.error == null;
	},
	delete_all: function(config, stype, comparator) {
		if (type(comparator) == 'object') {
			this.call('delete', {
				'config': config,
				'type': stype,
				'match': comparator,
			});
		} else if (type(comparator) == 'function') {
			const rv = this.call('get', {
				'config': config,
				'type': stype,
			});

			if (type(rv) == 'object' && type(rv.values) == 'object') {
				for (let sname, section in rv.values) {
					if (comparator(section)) {
						this.call('delete', {
							'config': config,
							'section': sname,
						});
					}
				}
			}
		} else if (comparator == null) {
			this.call('delete', {
				'config': config,
				'type': stype,
			});
		} else {
			//printf('uci.delete_all: Invalid argument\n');

			return false;
		}

		return this.error == null;
	},
};

function wrap_uci_ubus() {
	return proto({ ubus: connect(), error: null }, UbusUciWrapperClass);
}

export { wrap_uci_ubus };
