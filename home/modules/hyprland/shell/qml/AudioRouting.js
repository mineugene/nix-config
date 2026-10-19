function captureIdentity(properties) {
	return (
		properties["application.id"] ||
		properties["application.process.binary"] ||
		properties["application.name"] ||
		properties["node.name"] ||
		""
	);
}

function captureLabel(properties, identity) {
	return (
		properties["application.name"] ||
		properties["application.process.binary"] ||
		identity
	);
}

function captureApplications(nodes, targets) {
	var applications = {};
	var order = [];
	for (var i = 0; i < nodes.length; i++) {
		var node = nodes[i];
		var properties = node.properties || {};
		if (properties["media.class"] !== "Stream/Input/Audio") continue;
		var identity = captureIdentity(properties);
		if (!identity) continue;
		if (!applications[identity]) {
			applications[identity] = {
				identity: identity,
				label: captureLabel(properties, identity),
				nodes: [],
				target: null,
			};
			order.push(identity);
		}
		applications[identity].nodes.push(node);
		var target = targets[node.id];
		if (target && target !== "-1") applications[identity].target = target;
	}
	return order.map(function (identity) {
		return applications[identity];
	});
}

function parseMetadataLine(line) {
	if (typeof line !== "string") return null;
	var match = line.match(
		/^update: id:(\d+) key:'target\.object' value:'(.*)' type:/,
	);
	if (!match) return null;
	var id = Number(match[1]);
	var target = match[2];
	return { id: id, target: target && target !== "-1" ? target : null };
}

function updateCaptureTargets(targets, update) {
	var next = Object.assign({}, targets);
	if (update.target) next[update.id] = update.target;
	else delete next[update.id];
	return next;
}

if (typeof module !== "undefined") {
	module.exports = {
		captureIdentity: captureIdentity,
		captureApplications: captureApplications,
		parseMetadataLine: parseMetadataLine,
		updateCaptureTargets: updateCaptureTargets,
	};
}
