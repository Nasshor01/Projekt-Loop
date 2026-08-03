const fs = require("fs");
const path = require("path");

const files = [
  "data/artifacts/basic_artifact_pool.tres",
  "data/artifacts/pool/shop_pool.tres",
  "data/artifacts/pool/elite_reward_pool.tres",
  "data/artifacts/pool/treasure_room_pool.tres",
  "data/artifacts/pool/boss_reward_pool.tres",
  "data/artifacts/pool/event_reward_pool.tres",
];

for (const f of files) {
  let c = fs.readFileSync(f, "utf8");
  // Ensure ArtifactsData script is referenced as id="ad"
  if (!c.includes('path="res://data/artifacts/ArtifactsData.gd"')) {
    c = c.replace(
      '[ext_resource type="Script" path="res://data/artifacts/ArtifactPool.gd" id="1"]',
      '[ext_resource type="Script" path="res://data/artifacts/ArtifactsData.gd" id="ad"]\n[ext_resource type="Script" path="res://data/artifacts/ArtifactPool.gd" id="1"]'
    );
  }
  // Normalize artifacts array typing
  c = c.replace(
    /artifacts = Array\[[^\]]+\]\(\[/,
    'artifacts = Array[ExtResource("ad")](['
  );
  // bump load_steps if we added a resource
  const loadMatch = c.match(/load_steps=(\d+)/);
  if (loadMatch && c.includes('id="ad"')) {
    // recount ext_resources
    const extCount = (c.match(/\[ext_resource /g) || []).length;
    c = c.replace(/load_steps=\d+/, `load_steps=${extCount + 1}`);
  }
  fs.writeFileSync(f, c);
  console.log("fixed", f);
}
