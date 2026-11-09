--!strict
local TestKit = require("./TestKit")
local Market = require("../src/shared/Logic/Market")
local Config = require("../src/shared/Config")

return function(t: TestKit.TestKit)
	local prices = Market.priceTable(Config.Fish)

	t:test("prototype price is the base price", function()
		t:eq(prices.Sardine, 5)
		t:eq(prices.Angelfish, 150)
	end)

	t:test("total adds up every fish in the net", function()
		local net = { { id = "Sardine" }, { id = "Sardine" }, { id = "Clownfish" } }
		t:eq(Market.totalValue(net, prices), 30)
	end)

	t:test("empty net and unknown fish are worth nothing", function()
		t:eq(Market.totalValue({}, prices), 0)
		t:eq(Market.totalValue({ { id = "Kraken" } }, prices), 0)
	end)
end
