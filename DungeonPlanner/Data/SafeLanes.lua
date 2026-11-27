-- SafeLanes: well-known swims where the arrow may lead you even when the land beside them is
-- far above your level. Swimming offshore keeps you away from the mobs on the beach, so walking
-- costs along these lanes aren't raised for danger. Points are world yards ("x y"), following
-- the walking network's own coast line.
local _, ns = ...

ns.SAFE_LANES = {
    [0] = {
        -- Grom'gol Base Camp up the Stranglethorn coast to Westfall's south shore
        -- (the classic Horde way to Westfall; the Alliance way to Booty Bay in reverse).
        { radius = 160, points = "-12431 244 -12327 248 -12227 344 -12169 344 -12123 360 -12077 402 -12077 444 -12027 498 -11994 565 -11990 669 -11960 715 -11894 781 -11881 781 -11735 931 -11735 973 -11715 1015 -11710 1056 -11690 1085 -11690 1235 -11710 1265 -11710 1285 -11731 1306 -11719 1306 -11694 1331 -11681 1369 -11681 1419 -11540 1569 -11548 1602 -11531 1615 -11473 1673 -11465 1702 -11456 1715 -11444 1727 -11435 1731 -11410 1723 -11356 1715 -11202 1715 -11181 1723 " },
    },
}
