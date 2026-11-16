@tool
extends EditorScript

var DIR := ""


func _run():
	DIR = get_script().resource_path.get_base_dir() + "/data/"
	DirAccess.make_dir_recursive_absolute(DIR + "fusions")

	var tomato := load(DIR + "party/tomato.tres") as PartyMemberData
	var steak := load(DIR + "party/steak.tres") as PartyMemberData
	var soup := load(DIR + "party/soup.tres") as PartyMemberData

	_fusion("steak_sauce_slide", "Steak Sauce Shield", [tomato, steak], 1.5,
		"Tomato and Steak combine to make an acidic blockade!")
	_fusion("tomato_bisque_blast", "Tomato Bisque Blast", [tomato, soup], 1.5,
		"Tomato and Soup combine to make a fine acidic broth!")
	_fusion("steak_stew_smash", "Beef Stew Spill", [steak, soup], 1.5,
		"Steak and Soup combine into a  hearty slow simmered stew!")
	_fusion("grand_feast", "Grand Feast", [tomato, steak, soup], 2.5,
		"The whole party unleashes the last supper!")

	EditorInterface.get_resource_filesystem().scan()
	print("Done. Fusions are in ", DIR, "fusions/. New ones need to be dragged into Team > Fusions.")


func _fusion(file: String, fusion_name: String, partners: Array, mult: float, text: String):
	var path := DIR + "fusions/%s.tres" % file
	var f: FusionData
	if ResourceLoader.exists(path):
		# Existing file: only refresh name + text, keep everything else you've edited
		f = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as FusionData
	else:
		f = FusionData.new()
		f.mult = mult
		f.vfx_target = "enemy"
		for p in partners:
			f.partners.append(p)
	f.name = fusion_name
	f.text = text
	ResourceSaver.save(f, path)
