import Foundation

struct EmojiCategory {
    let iconName: String
    let title: String
    let emojis: [String]

    init(iconName: String, title: String, emojis: String) {
        self.iconName = iconName
        self.title = title
        self.emojis = emojis.split(separator: " ").map(String.init)
    }
}

enum EmojiCatalog {
    static let categories = [
        EmojiCategory(
            iconName: "face.smiling",
            title: "Smileys",
            emojis: "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🫣 🤭 🫢 🫡 🤫 🫠 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕"
        ),
        EmojiCategory(
            iconName: "hand.raised.fill",
            title: "People",
            emojis: "👋 🤚 🖐️ ✋ 🖖 🫱 🫲 🫳 🫴 👌 🤌 🤏 ✌️ 🤞 🫰 🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝️ 🫵 👍 👎 ✊ 👊 🤛 🤜 👏 🙌 🫶 👐 🤲 🤝 🙏 ✍️ 💅 🤳 💪 🦾 🦿 🦵 🦶 👂 👃 🧠 🫀 🫁 🦷 👀 👁️ 👅 👄 🫦 👶 🧒 👦 👧 🧑 👱 👨 🧔 👩 🧓 👴 👵"
        ),
        EmojiCategory(
            iconName: "leaf.fill",
            title: "Nature",
            emojis: "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐻‍❄️ 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🙈 🙉 🙊 🐒 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🪱 🐛 🦋 🐌 🐞 🐜 🪰 🪲 🪳 🦟 🦗 🕷️ 🦂 🐢 🐍 🦎 🐙 🦑 🦐 🦞 🦀 🐠 🐟 🐬 🐳 🌵 🎄 🌲 🌳 🌴 🌱 🌿 ☘️ 🍀 🍁 🍂 🍃 🌺 🌸 🌼 🌻"
        ),
        EmojiCategory(
            iconName: "fork.knife",
            title: "Food",
            emojis: "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶️ 🫑 🌽 🥕 🫒 🧄 🧅 🥔 🍠 🥐 🥯 🍞 🥖 🥨 🧀 🥚 🍳 🧈 🥞 🧇 🥓 🥩 🍗 🍖 🌭 🍔 🍟 🍕 🫓 🥪 🥙 🧆 🌮 🌯 🫔 🥗 🍝 🍜 🍲 🍛 🍣 🍱 🥟 🍤 🍙 🍚 🍘 🍥 🥠 🍦 🍩 🍪 🎂 🍰 🧁 🍫 🍿 ☕️ 🧃 🥤"
        ),
        EmojiCategory(
            iconName: "soccerball",
            title: "Activities",
            emojis: "⚽️ 🏀 🏈 ⚾️ 🥎 🎾 🏐 🏉 🥏 🎱 🪀 🏓 🏸 🏒 🏑 🥍 🏏 🪃 🥅 ⛳️ 🪁 🏹 🎣 🤿 🥊 🥋 🎽 🛹 🛼 🛷 ⛸️ 🥌 🎿 ⛷️ 🏂 🪂 🏋️ 🤼 🤸 ⛹️ 🤺 🤾 🏌️ 🏇 🧘 🏄 🏊 🤽 🚣 🧗 🚵 🚴 🏆 🥇 🥈 🥉 🎯 🎮 🎲 🧩 🎨 🎭 🎤 🎧 🎸 🎹 🥁"
        ),
        EmojiCategory(
            iconName: "car.fill",
            title: "Travel",
            emojis: "🚗 🚕 🚙 🚌 🚎 🏎️ 🚓 🚑 🚒 🚐 🛻 🚚 🚛 🚜 🏍️ 🛵 🚲 🛴 🚨 🚔 🚍 🚘 🚖 ✈️ 🛫 🛬 🛩️ 💺 🚁 🚀 🛸 🚉 🚆 🚄 🚅 🚈 🚂 🚊 🚝 🚞 🚋 🚢 ⛵️ 🚤 🛥️ 🛳️ ⛴️ ⚓️ 🗿 🗽 🗼 🏰 🏯 🎡 🎢 🎠 ⛲️ ⛺️ 🌋 🏜️ 🏝️ 🏖️ 🏕️ 🌅 🌄 🌠 🎇 🎆 🌇 🌆 🏙️ 🌃 🌌"
        ),
        EmojiCategory(
            iconName: "lightbulb.fill",
            title: "Objects",
            emojis: "⌚️ 📱 💻 ⌨️ 🖥️ 🖨️ 🖱️ 💽 💾 💿 📀 🧮 🎥 📷 📸 📹 📺 📻 🎙️ ⏱️ ⏰ 🕰️ ⌛️ 📡 🔋 🪫 🔌 💡 🔦 🕯️ 🧯 🛢️ 💸 💵 💰 💳 💎 ⚖️ 🪜 🧰 🪛 🔧 🔨 ⚒️ 🛠️ ⛏️ 🪚 🔩 ⚙️ 🧱 ⛓️ 🧲 🔫 💣 🧨 🪓 🔪 🛡️ 🚬 ⚰️ 🔮 🧿 💈 ⚗️ 🔭 🔬 💊 💉 🩹 🩺 🚪 🪑 🛏️ 🚿 🛁 🧴 🧹 🧺 🧻 🪥 🧼 🔑"
        ),
        EmojiCategory(
            iconName: "heart.fill",
            title: "Symbols",
            emojis: "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❤️‍🔥 ❤️‍🩹 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ☮️ ✝️ ☪️ 🕉️ ☸️ ✡️ 🔯 🕎 ☯️ ☦️ 🛐 ⛎ ♈️ ♉️ ♊️ ♋️ ♌️ ♍️ ♎️ ♏️ ♐️ ♑️ ♒️ ♓️ 🆔 ⚛️ ☢️ ☣️ 📴 📳 🈶 🈚️ 🈸 🈺 🈷️ ✴️ 🆚 💮 🉐 ㊙️ ㊗️ 🈴 🈵 🈹 🈲 🅰️ 🅱️ 🆎 🆑 🅾️ 🆘 ❌ ⭕️ 🛑 ⛔️ 💯 💢 ♨️ 🚷 🚯 🚳 🚱 🔞 📵"
        ),
        EmojiCategory(
            iconName: "flag.fill",
            title: "Flags",
            emojis: "🏁 🚩 🎌 🏴 🏳️ 🏳️‍🌈 🏳️‍⚧️ 🇺🇳 🇺🇸 🇬🇧 🇨🇦 🇦🇺 🇮🇳 🇵🇰 🇧🇩 🇱🇰 🇳🇵 🇯🇵 🇨🇳 🇰🇷 🇸🇬 🇲🇾 🇮🇩 🇵🇭 🇹🇭 🇻🇳 🇦🇪 🇸🇦 🇶🇦 🇹🇷 🇩🇪 🇫🇷 🇮🇹 🇪🇸 🇵🇹 🇳🇱 🇧🇪 🇨🇭 🇦🇹 🇸🇪 🇳🇴 🇩🇰 🇫🇮 🇮🇪 🇵🇱 🇺🇦 🇬🇷 🇧🇷 🇦🇷 🇲🇽 🇿🇦 🇳🇬 🇪🇬 🇲🇦 🇳🇿"
        )
    ]
}
