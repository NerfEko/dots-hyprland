pragma Singleton
import Quickshell

Singleton {
    id: root

    /**
     * Formats a string according to the args that are passed inc
     * @param { string } str
     * @param  {...any} args
     * @returns { string }
     */
    function format(str, ...args) {
        return str.replace(/{(\d+)}/g, (match, index) => typeof args[index] !== 'undefined' ? args[index] : match);
    }

    /**
     * Returns the domain of the passed in url or null
     * @param { string } url
     * @returns { string| null }
     */
    function getDomain(url) {
        const match = url.match(/^(?:https?:\/\/)?(?:www\.)?([^\/]+)/);
        return match ? match[1] : null;
    }

    /**
     * Returns the base url of the passed in url or null
     * @param { string } url
     * @returns { string | null }
     */
    function getBaseUrl(url) {
        const match = url.match(/^(https?:\/\/[^\/]+)(\/.*)?$/);
        return match ? match[1] : null;
    }

    /**
     * Escapes single quotes in shell commands
     * @param { string } str
     * @returns { string }
     */
    function shellSingleQuoteEscape(str) {
        return String(str)
        // .replace(/\\/g, '\\\\')
        .replace(/'/g, "'\\''");
    }

    /**
     * Splits markdown blocks into four different types: text, think, code, and tool.
     * @param { string } markdown
     * @returns {Array<{type: "text" | "think" | "code" | "tool", content: string, lang?: string, completed?: boolean, toolName?: string, toolTitle?: string, toolStatus?: string, toolInput?: string}>}
     */
    function splitMarkdownBlocks(markdown) {
        const regex = /```(\w+)?\n([\s\S]*?)```|<think>([\s\S]*?)<\/think>|<tool\s+([^>]*)>([\s\S]*?)<\/tool>/g;
        /**
         * @type {{type: "text" | "think" | "code" | "tool"; content: string; lang: string | undefined; completed: boolean | undefined; toolName: string | undefined; toolTitle: string | undefined; toolStatus: string | undefined; toolInput: string | undefined}[]}
         */
        let result = [];
        let lastIndex = 0;
        let match;
        while ((match = regex.exec(markdown)) !== null) {
            if (match.index > lastIndex) {
                const text = markdown.slice(lastIndex, match.index);
                if (text.trim()) {
                    result.push({
                        type: "text",
                        content: text
                    });
                }
            }
            if (match[0].startsWith('```')) {
                if (match[2] && match[2].trim()) {
                    result.push({
                        type: "code",
                        lang: match[1] || "",
                        content: match[2],
                        completed: true
                    });
                }
            } else if (match[0].startsWith('<think>')) {
                if (match[3] && match[3].trim()) {
                    result.push({
                        type: "think",
                        content: match[3],
                        completed: true
                    });
                }
            } else if (match[0].startsWith('<tool')) {
                const attrs = root.parseToolAttributes(match[4] || "");
                result.push({
                    type: "tool",
                    content: match[5] || "",
                    toolName: attrs.name || "tool",
                    toolTitle: (attrs.title || "").replace(/&quot;/g, '"'),
                    toolStatus: attrs.status || "running",
                    toolInput: (attrs.input || "").replace(/&quot;/g, '"'),
                    completed: attrs.status === "completed" || attrs.status === "error"
                });
            }
            lastIndex = regex.lastIndex;
        }
        // Handle any remaining text after the last match
        if (lastIndex < markdown.length) {
            const text = markdown.slice(lastIndex);
            // Check for unfinished blocks - find the earliest start
            const thinkStart = text.indexOf('<think>');
            const codeStart = text.indexOf('```');
            const toolStart = text.indexOf('<tool');

            // Find which unfinished block comes first
            let firstStart = -1;
            let firstType = "";
            if (thinkStart !== -1 && (firstStart === -1 || thinkStart < firstStart)) { firstStart = thinkStart; firstType = "think"; }
            if (codeStart !== -1 && (firstStart === -1 || codeStart < firstStart)) { firstStart = codeStart; firstType = "code"; }
            if (toolStart !== -1 && (firstStart === -1 || toolStart < firstStart)) { firstStart = toolStart; firstType = "tool"; }

            if (firstType === "think") {
                const beforeThink = text.slice(0, thinkStart);
                if (beforeThink.trim()) {
                    result.push({
                        type: "text",
                        content: beforeThink
                    });
                }
                const thinkContent = text.slice(thinkStart + 7);
                if (thinkContent.trim()) {
                    result.push({
                        type: "think",
                        content: thinkContent,
                        completed: false
                    });
                }
            } else if (firstType === "tool") {
                const beforeTool = text.slice(0, toolStart);
                if (beforeTool.trim()) {
                    result.push({
                        type: "text",
                        content: beforeTool
                    });
                }
                // Parse attributes from the opening tag
                const tagEndIdx = text.indexOf('>', toolStart);
                if (tagEndIdx !== -1) {
                    const attrStr = text.slice(toolStart + 5, tagEndIdx);
                    const attrs = root.parseToolAttributes(attrStr);
                    const toolContent = text.slice(tagEndIdx + 1);
                    result.push({
                        type: "tool",
                        content: toolContent,
                        toolName: attrs.name || "tool",
                        toolTitle: (attrs.title || "").replace(/&quot;/g, '"'),
                        toolStatus: attrs.status || "running",
                        toolInput: (attrs.input || "").replace(/&quot;/g, '"'),
                        completed: false
                    });
                }
            } else if (firstType === "code") {
                const beforeCode = text.slice(0, codeStart);
                if (beforeCode.trim()) {
                    result.push({
                        type: "text",
                        content: beforeCode
                    });
                }
                // Try to detect language after ```
                const codeLangMatch = text.slice(codeStart + 3).match(/^(\w+)?\n/);
                let lang = "";
                let codeContentStart = codeStart + 3;
                if (codeLangMatch) {
                    lang = codeLangMatch[1] || "";
                    codeContentStart += codeLangMatch[0].length;
                } else if (text[codeStart + 3] === '\n') {
                    codeContentStart += 1;
                }
                const codeContent = text.slice(codeContentStart);
                if (codeContent.trim()) {
                    result.push({
                        type: "code",
                        lang,
                        content: codeContent,
                        completed: false
                    });
                }
            } else if (text.trim()) {
                result.push({
                    type: "text",
                    content: text
                });
            }
        }
        // console.log(JSON.stringify(result, null, 2));
        return result;
    }

    /**
     * Parses HTML-style attributes from a tag string.
     * e.g. 'name="read" title="Reading file" status="completed"' => {name: "read", title: "Reading file", status: "completed"}
     * @param { string } attrString
     * @returns { Object }
     */
    function parseToolAttributes(attrString) {
        let attrs = {};
        const regex = /(\w+)="([^"]*)"/g;
        let m;
        while ((m = regex.exec(attrString)) !== null) {
            attrs[m[1]] = m[2];
        }
        return attrs;
    }

    /**
     * Returns the original string with backslashes escaped
     * @param { string } str
     * @returns { string }
     */
    function escapeBackslashes(str) {
        return str.replace(/\\/g, '\\\\');
    }

    /**
     * Wraps words to supplied maximum length
     * @param { string | null } str
     * @param { number } maxLen
     * @returns { string }
     */
    function wordWrap(str, maxLen) {
        if (!str)
            return "";
        let words = str.split(" ");
        let lines = [];
        let current = "";
        for (let i = 0; i < words.length; ++i) {
            if ((current + (current.length > 0 ? " " : "") + words[i]).length > maxLen) {
                if (current.length > 0)
                    lines.push(current);
                current = words[i];
            } else {
                current += (current.length > 0 ? " " : "") + words[i];
            }
        }
        if (current.length > 0)
            lines.push(current);
        return lines.join("\n");
    }

    /**
     * Cleans up a music title by removing bracketed and special characters.
     * @param { string } title
     * @returns { string }
     */
    function cleanMusicTitle(title) {
        if (!title)
            return "";
        // Brackets
        title = title.replace(/^ *\([^)]*\) */g, " "); // Round brackets
        title = title.replace(/^ *\[[^\]]*\] */g, " "); // Square brackets
        title = title.replace(/^ *\{[^\}]*\} */g, " "); // Curly brackets
        // Japenis brackets
        title = title.replace(/^ *【[^】]*】/, ""); // Touhou
        title = title.replace(/^ *《[^》]*》/, ""); // ??
        title = title.replace(/^ *「[^」]*」/, ""); // OP/ED thingie
        title = title.replace(/^ *『[^』]*』/, ""); // OP/ED thingie

        return title.trim();
    }

    /**
     * Converts seconds to a friendly time string (e.g. 1:23 or 1:02:03).
     * @param { number } seconds
     * @returns { string }
     */
    function friendlyTimeForSeconds(seconds) {
        if (isNaN(seconds) || seconds < 0)
            return "0:00";
        seconds = Math.floor(seconds);
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        if (h > 0) {
            return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
        } else {
            return `${m}:${s.toString().padStart(2, '0')}`;
        }
    }

    /**
     * Escapes HTML special characters in a string.
     * @param { string } str
     * @returns { string }
     */
    function escapeHtml(str) {
        if (typeof str !== 'string')
            return str;
        return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    /**
     * Cleans a cliphist entry by removing leading digits and tab.
     * @param { string } str
     * @returns { string }
     */
    function cleanCliphistEntry(str: string): string {
        return str.replace(/^\d+\t/, "");
    }

    /**
     * Checks if any substring in the list is contained in the string.
     * @param { string } str
     * @param { string[] } substrings
     * @returns { boolean }
     */
    function stringListContainsSubstring(str, substrings) {
        for (let i = 0; i < substrings.length; ++i) {
            if (str.includes(substrings[i])) {
                return true;
            }
        }
        return false;
    }

    /**
     * Removes the given prefix from the string if present.
     * @param { string } str
     * @param { string } prefix
     * @returns { string }
     */
    function cleanPrefix(str, prefix) {
        if (str.startsWith(prefix)) {
            return str.slice(prefix.length);
        }
        return str;
    }

    /**
     * Removes the first matching prefix from the string if present.
     * @param { string } str
     * @param { string[] } prefixes
     * @returns { string }
     */
    function cleanOnePrefix(str, prefixes) {
        for (let i = 0; i < prefixes.length; ++i) {
            if (str.startsWith(prefixes[i])) {
                return str.slice(prefixes[i].length);
            }
        }
        return str;
    }

    function toTitleCase(str) {
        // Replace "-" and "_" with space, then capitalize each word
        return str.replace(/[-_]/g, " ").replace(
            /\w\S*/g,
            function(txt) {
            return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
            }
        );
    }

    /**
     * Converts markdown text to HTML for rendering with Text.RichText.
     * Handles: headers, bold, italic, strikethrough, inline code, links, images,
     * lists, blockquotes, tables, horizontal rules, and passes through raw HTML.
     * @param { string } md - The markdown text
     * @param { string } textColor - CSS color for normal text (default: inherit)
     * @param { string } linkColor - CSS color for links
     * @param { string } codeBackground - CSS color for inline code background
     * @param { string } codeForeground - CSS color for inline code text
     * @param { string } quoteColor - CSS color for blockquote text
     * @param { string } quoteBorderColor - CSS color for blockquote border
     * @returns { string } HTML string
     */
    function markdownToHtml(md, textColor, linkColor, codeBackground, codeForeground, quoteColor, quoteBorderColor) {
        if (!md) return "";
        textColor = textColor || "inherit";
        linkColor = linkColor || "#7cacf8";
        codeBackground = codeBackground || "rgba(255,255,255,0.08)";
        codeForeground = codeForeground || "#e0b0ff";
        quoteColor = quoteColor || "rgba(255,255,255,0.6)";
        quoteBorderColor = quoteBorderColor || "rgba(255,255,255,0.3)";

        // Normalize line endings
        md = md.replace(/\r\n/g, "\n").replace(/\r/g, "\n");

        // Process block-level elements
        const lines = md.split("\n");
        let html = "";
        let i = 0;
        let inList = false;      // "ul" or "ol" or false
        let listIndent = 0;

        function closeList() {
            if (inList) {
                html += inList === "ul" ? "</ul>" : "</ol>";
                inList = false;
            }
        }

        while (i < lines.length) {
            let line = lines[i];

            // Blank line
            if (line.trim() === "") {
                closeList();
                html += "<br/>";
                i++;
                continue;
            }

            // Horizontal rule: --- or *** or ___
            if (/^\s{0,3}([-*_])\s*\1\s*\1(\s*\1)*\s*$/.test(line)) {
                closeList();
                html += '<hr/>';
                i++;
                continue;
            }

            // Headers: # to ######
            const headerMatch = line.match(/^(#{1,6})\s+(.*)$/);
            if (headerMatch) {
                closeList();
                const level = headerMatch[1].length;
                const content = processInline(headerMatch[2]);
                html += '<h' + level + '>' + content + '</h' + level + '>';
                i++;
                continue;
            }

            // Table: detect a row starting with |
            if (line.trim().startsWith("|")) {
                closeList();
                const tableLines = [];
                while (i < lines.length && lines[i].trim().startsWith("|")) {
                    tableLines.push(lines[i]);
                    i++;
                }
                html += renderTable(tableLines);
                continue;
            }

            // Blockquote: > text
            const quoteMatch = line.match(/^>\s?(.*)/);
            if (quoteMatch) {
                closeList();
                const quoteLines = [];
                while (i < lines.length && lines[i].match(/^>\s?(.*)/)) {
                    quoteLines.push(lines[i].replace(/^>\s?/, ""));
                    i++;
                }
                const quoteContent = quoteLines.map(l => processInline(l)).join("<br/>");
                html += '<table cellpadding="0" cellspacing="0" style="margin: 4px 0;"><tr>'
                    + '<td width="3" style="background-color: ' + quoteBorderColor + ';"></td>'
                    + '<td style="padding-left: 10px; color: ' + quoteColor + '; font-style: italic;">'
                    + quoteContent + '</td></tr></table>';
                continue;
            }

            // Unordered list: - item, * item, + item
            const ulMatch = line.match(/^(\s*)([-*+])\s+(.*)/);
            if (ulMatch) {
                if (inList !== "ul") {
                    closeList();
                    html += "<ul>";
                    inList = "ul";
                }
                html += "<li>" + processInline(ulMatch[3]) + "</li>";
                i++;
                continue;
            }

            // Ordered list: 1. item
            const olMatch = line.match(/^(\s*)(\d+)\.\s+(.*)/);
            if (olMatch) {
                if (inList !== "ol") {
                    closeList();
                    html += "<ol>";
                    inList = "ol";
                }
                html += "<li>" + processInline(olMatch[3]) + "</li>";
                i++;
                continue;
            }

            // Regular paragraph
            closeList();
            html += '<p>' + processInline(line) + '</p>';
            i++;
        }
        closeList();

        return html;

        // --- Inline processing ---
        function processInline(text) {
            if (!text) return "";

            // Protect inline code first (backticks)
            const codeSpans = [];
            text = text.replace(/`([^`]+)`/g, function(match, code) {
                const idx = codeSpans.length;
                // Qt Rich Text supports <span style="..."> with background-color and font-family
                codeSpans.push('<span style="background-color: ' + codeBackground + '; color: ' + codeForeground + '; font-family: monospace;">&nbsp;' + escapeHtml(code) + '&nbsp;</span>');
                return "%%CODESPAN" + idx + "%%";
            });

            // Images: ![alt](url)
            text = text.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '<img src="$2" alt="$1" />');

            // Links: [text](url)
            text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" style="color: ' + linkColor + '; text-decoration: none;">$1</a>');

            // Bold + italic: ***text*** or ___text___
            text = text.replace(/\*\*\*(.+?)\*\*\*/g, '<b><i>$1</i></b>');
            text = text.replace(/___(.+?)___/g, '<b><i>$1</i></b>');

            // Bold: **text** or __text__
            text = text.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');
            text = text.replace(/__(.+?)__/g, '<b>$1</b>');

            // Italic: *text* or _text_ (but not mid-word underscores)
            text = text.replace(/\*(.+?)\*/g, '<i>$1</i>');
            text = text.replace(/(^|[^a-zA-Z0-9])_(.+?)_([^a-zA-Z0-9]|$)/g, '$1<i>$2</i>$3');

            // Strikethrough: ~~text~~
            text = text.replace(/~~(.+?)~~/g, '<span style="text-decoration: line-through;">$1</span>');

            // Restore inline code spans
            text = text.replace(/%%CODESPAN(\d+)%%/g, function(match, idx) {
                return codeSpans[parseInt(idx)];
            });

            return text;
        }

        // --- Table rendering ---
        function renderTable(tableLines) {
            if (tableLines.length < 2) return "";

            function parseCells(line) {
                // Remove leading/trailing pipes and split
                return line.replace(/^\|/, "").replace(/\|$/, "").split("|").map(c => c.trim());
            }

            const headerCells = parseCells(tableLines[0]);
            // Check if second line is separator (---|----|---)
            let startRow = 1;
            let alignments = [];
            if (tableLines.length > 1 && /^[\s|:-]+$/.test(tableLines[1])) {
                const sepCells = parseCells(tableLines[1]);
                alignments = sepCells.map(function(cell) {
                    if (cell.startsWith(":") && cell.endsWith(":")) return "center";
                    if (cell.endsWith(":")) return "right";
                    return "left";
                });
                startRow = 2;
            }

            let t = '<table cellpadding="4" cellspacing="0" style="border-collapse: collapse; margin: 4px 0; width: 100%;">';
            // Header row
            t += "<tr>";
            for (let h = 0; h < headerCells.length; h++) {
                const align = alignments[h] || "left";
                t += '<th style="border-bottom: 2px solid rgba(255,255,255,0.2); text-align: ' + align + '; padding: 4px 8px; font-weight: bold;">' + processInline(headerCells[h]) + '</th>';
            }
            t += "</tr>";

            // Data rows
            for (let r = startRow; r < tableLines.length; r++) {
                const cells = parseCells(tableLines[r]);
                t += "<tr>";
                for (let c = 0; c < cells.length; c++) {
                    const align = alignments[c] || "left";
                    t += '<td style="border-bottom: 1px solid rgba(255,255,255,0.08); text-align: ' + align + '; padding: 4px 8px;">' + processInline(cells[c]) + '</td>';
                }
                t += "</tr>";
            }
            t += "</table>";
            return t;
        }
    }
}
