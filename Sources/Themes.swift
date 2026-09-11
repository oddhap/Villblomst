import AppKit

struct WallpaperTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let symbols: [String]
    let keywords: [String]

    var icon: String {
        symbols.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil } ?? "circle"
    }

    func matches(_ title: String) -> Bool {
        if keywords.isEmpty { return true }
        let cleaned = Scraper.decodeHTML(title).lowercased()
        let tokens = Set(cleaned.split(whereSeparator: { !$0.isLetter }).map(String.init))
        for keyword in keywords {
            if keyword.contains(" ") {
                if cleaned.contains(keyword) { return true }
            } else if tokens.contains(keyword) {
                return true
            }
        }
        return false
    }

    static let all: [WallpaperTheme] = [
        WallpaperTheme(id: "alle", name: "Alle", symbols: ["square.grid.2x2", "sparkles"], keywords: []),

        WallpaperTheme(id: "blomster", name: "Blomster", symbols: ["camera.macro", "leaf.fill"], keywords: [
            "flower", "flowers", "wildflower", "wildflowers", "blossom", "blossoms",
            "bloom", "blooms", "blooming", "flowering", "meadow", "meadows",
            "garden", "gardens", "botanical", "botanic", "tulip", "tulips",
            "rose", "roses", "orchid", "orchids", "daisy", "poppy", "poppies",
            "lavender", "sunflower", "sunflowers", "lilies", "lily", "iris",
            "fern", "ferns", "petal", "petals", "flora", "cactus", "succulent",
            "clover", "bluebell", "bluebells", "foxglove", "thistle", "dandelion",
            "magnolia", "hibiscus", "anemone", "anemones", "hydrangea", "peony",
            "peonies", "jasmine", "azalea", "azaleas", "rhododendron",
            "rhododendrons", "wisteria", "lupine", "lupines", "lupin", "lotus",
            "violet", "violets", "pansy", "geranium", "begonia", "camellia",
            "coneflower", "cornflower", "snapdragon", "marigold", "verbena",
            "chicory", "buttercup", "primrose", "gentian", "fireweed", "heather",
            "crocus", "crocuses", "hyacinth", "hyacinths", "dahlia", "protea",
            "trillium", "balsamroot", "phlox", "narcissus", "daffodil",
            "daffodils", "allium", "fuchsia", "water lily", "water lilies"
        ]),

        WallpaperTheme(id: "natur", name: "Natur", symbols: ["tree", "leaf"], keywords: [
            "forest", "forests", "tree", "trees", "woodland", "rainforest",
            "jungle", "mountain", "mountains", "valley", "canyon", "canyons",
            "glacier", "glaciers", "volcano", "waterfall", "waterfalls", "river",
            "lake", "lakes", "meadow", "meadows", "wilderness", "cliff", "cliffs",
            "hill", "hills", "grassland", "savanna", "steppe", "prairie",
            "tundra", "swamp", "marsh", "geyser", "cave", "caves", "pine", "pines",
            "sequoia", "redwood", "bamboo", "autumn", "blooming", "coral",
            "reef", "lagoon", "fjord", "badlands", "desert", "dunes"
        ]),

        WallpaperTheme(id: "dyr", name: "Dyr", symbols: ["pawprint.fill", "tortoise.fill"], keywords: [
            "bear", "bears", "fox", "foxes", "wolf", "wolves", "deer", "elk",
            "moose", "reindeer", "bird", "birds", "eagle", "owl", "owls",
            "butterfly", "butterflies", "bee", "bees", "whale", "whales", "shark",
            "sharks", "dolphin", "dolphins", "seal", "seals", "penguin",
            "penguins", "elephant", "elephants", "lion", "lions", "tiger",
            "tigers", "leopard", "cheetah", "monkey", "monkeys", "giraffe",
            "giraffes", "zebra", "zebras", "turtle", "turtles", "frog", "frogs",
            "lizard", "snake", "snakes", "squirrel", "rabbit", "rabbits", "hare",
            "horse", "horses", "cattle", "sheep", "goat", "cats", "dogs", "crab",
            "octopus", "fish", "fishes", "hummingbird", "flamingo", "crane",
            "swan", "duck", "geese", "parrot", "toucan", "puffin", "heron",
            "kingfisher", "rhino", "hippopotamus", "bison", "camel", "llama",
            "alpaca", "kangaroo", "koala", "panda", "orangutan", "lemur",
            "walrus", "manatee", "macaw", "macaws", "toucan", "owlet", "lions"
        ]),

        WallpaperTheme(id: "by", name: "By", symbols: ["building.2.fill", "building.columns.fill"], keywords: [
            "city", "cityscape", "skyline", "building", "buildings", "architecture",
            "street", "streets", "town", "village", "bridge", "bridges", "harbor",
            "harbour", "downtown", "skyscraper", "skyscrapers", "temple", "tower",
            "towers", "castle", "church", "cathedral", "mosque", "palace",
            "market", "alley", "avenue", "metro", "subway", "cafe", "boulevard",
            "waterfront", "district", "rooftops", "urban", "village", "homes",
            "boats", "canal"
        ]),

        WallpaperTheme(id: "landskap", name: "Landskap", symbols: ["mountain.2.fill", "photo"], keywords: [
            "landscape", "desert", "canyon", "valley", "valleys", "hills",
            "plateau", "mesa", "coast", "coastline", "dunes", "field", "fields",
            "farmland", "terrace", "terraces", "sunrise", "sunset", "horizon",
            "badlands", "fjord", "glacier", "mountains", "mountain", "cliffs",
            "cliff", "prairie", "savanna", "valley", "river", "lake"
        ]),

        WallpaperTheme(id: "hav", name: "Hav og vann", symbols: ["water.waves", "drop.fill"], keywords: [
            "ocean", "sea", "beach", "beaches", "coast", "coastline", "island",
            "islands", "lagoon", "reef", "coral", "underwater", "bay", "gulf",
            "harbor", "harbour", "waves", "tide", "shore", "shoreline", "pier",
            "lighthouse", "boat", "boats", "ship", "sailboat", "kayak", "surf",
            "lake", "river", "waterfall", "waterfalls", "water", "iceberg"
        ]),

        WallpaperTheme(id: "verdensrom", name: "Verdensrom", symbols: ["moon.stars.fill", "star.fill", "sparkles"], keywords: [
            "space", "galaxy", "galaxies", "milky way", "aurora", "auroras",
            "northern lights", "stars", "starry", "nebula", "moon", "planet",
            "planets", "saturn", "jupiter", "mars", "comet", "meteor", "eclipse",
            "observatory", "telescope", "nasa", "astronaut", "star trails",
            "night sky"
        ]),

        WallpaperTheme(id: "host", name: "Høst og vinter", symbols: ["snowflake", "leaf.fill"], keywords: [
            "autumn", "fall", "winter", "snow", "snowy", "frost", "frosty",
            "ice", "frozen", "hoarfrost", "maple", "leaves", "pumpkin",
            "christmas", "holiday", "holidays", "mistletoe", "pine", "pinecone"
        ])
    ]
}
