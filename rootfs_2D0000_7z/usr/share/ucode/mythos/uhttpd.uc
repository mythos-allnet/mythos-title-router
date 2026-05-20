{%

import request from 'luci.http';
import dispatch from 'mythos.dispatcher';

global.handle_request = function(env) {
	const req = request(env, uhttpd.recv, uhttpd.send);

	dispatch(req);

	req.close();
};
