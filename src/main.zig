// Copyright (C) 2021 Chadwain Holness
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const os = std.os;

const aio = @import("yozz/aio");

const assert = std.debug.assert;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try std.net.Address.resolveIp6("::0", 4000);

    var sock = try aio.linux.Socket.init(allocator, os.SOCK.STREAM);
    try sock.bind(address);
    try sock.listen();

    while(true) {}
}