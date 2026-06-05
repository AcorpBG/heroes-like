#pragma once

#include <godot_cpp/classes/node.hpp>

namespace godot {

class RmgNativeBatchExportRunner : public Node {
	GDCLASS(RmgNativeBatchExportRunner, Node)

protected:
	static void _bind_methods();

public:
	void _ready() override;
};

} // namespace godot
