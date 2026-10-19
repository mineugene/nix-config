"use strict";

const assert = require("assert");
const Routing = require(process.argv[2]);

const nodes = [
	{
		id: 41,
		properties: {
			"media.class": "Stream/Input/Audio",
			"application.id": "org.obsproject.Studio",
			"application.name": "OBS Studio",
			"application.process.binary": "obs",
		},
	},
	{
		id: 42,
		properties: {
			"media.class": "Stream/Input/Audio",
			"application.id": "org.obsproject.Studio",
			"application.name": "OBS Studio",
			"application.process.binary": "obs",
		},
	},
	{
		id: 43,
		properties: {
			"media.class": "Stream/Output/Audio",
			"application.name": "Playback only",
		},
	},
	{
		id: 44,
		properties: {
			"media.class": "Stream/Input/Audio",
			"application.name": "REC",
			"application.process.binary": "recorder",
		},
	},
];
const apps = Routing.captureApplications(nodes, {
	41: "OpenXLR_stream",
	42: "OpenXLR_stream",
});
assert.strictEqual(apps.length, 2);
assert.strictEqual(apps[0].identity, "org.obsproject.Studio");
assert.strictEqual(apps[0].label, "OBS Studio");
assert.deepStrictEqual(
	apps[0].nodes.map((node) => node.id),
	[41, 42],
);
assert.strictEqual(apps[0].target, "OpenXLR_stream");
assert.strictEqual(apps[1].identity, "recorder");
assert.strictEqual(apps[1].target, null);

assert.deepStrictEqual(
	Routing.parseMetadataLine(
		"update: id:41 key:'target.object' value:'OpenXLR_chat' type:'Spa:Id'",
	),
	{ id: 41, target: "OpenXLR_chat" },
);
assert.deepStrictEqual(
	Routing.parseMetadataLine(
		"update: id:41 key:'target.object' value:'-1' type:'Spa:Id'",
	),
	{ id: 41, target: null },
);
assert.strictEqual(
	Routing.parseMetadataLine(
		"update: id:0 key:'default.audio.source' value:'{}' type:'Spa:String:JSON'",
	),
	null,
);
const updated = Routing.updateCaptureTargets(
	{ 41: "OpenXLR_stream" },
	{
		id: 41,
		target: "OpenXLR_chat",
	},
);
assert.deepStrictEqual(updated, { 41: "OpenXLR_chat" });
assert.deepStrictEqual(
	Routing.updateCaptureTargets(updated, { id: 41, target: null }),
	{},
);

console.log("audio routing model ok");
