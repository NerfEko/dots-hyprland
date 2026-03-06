import App from 'resource:///com/github/Aylur/ags/app.js';
import Widget from 'resource:///com/github/Aylur/ags/widget.js';
import * as Utils from 'resource:///com/github/Aylur/ags/utils.js';
const { Box, Button, Label, Scrollable, Overlay } = Widget;
const { execAsync, exec } = Utils;
import { MaterialIcon } from '../../.commonwidgets/materialicon.js';
import { setupCursorHover } from '../../.widgetutils/cursorhover.js';

const VPN_STATUS_SCRIPT = `${App.configDir}/scripts/protonvpn/vpn_status.sh`;

// Returns a CSS color string for a given load percentage
const loadColor = (load) => {
    if (load < 0)   return 'rgba(255,255,255,0.2)';
    if (load < 50)  return '#5eba7d'; // green
    if (load < 75)  return '#f6a623'; // yellow
    return '#e05c5c';                 // red
};

const VpnServerRow = (server, activeNmName) => {
    const isActive  = server.nm_name === activeNmName;
    const loadKnown = server.load >= 0;
    const loadPct   = loadKnown ? `${server.load}%` : '—';

    const leftIcon = MaterialIcon(server.fastest ? 'bolt' : 'vpn_key', 'norm', {
        vpack: 'center',
        tooltipText: server.fastest ? getString('Fastest server') : '',
    });

    const nameLabel = Label({
        hpack: 'start',
        truncate: 'end',
        maxWidthChars: 1,
        className: `txt-small${server.fastest ? ' txt-bold' : ''}`,
        label: server.name,
    });

    const cityLabel = Label({
        hpack: 'start',
        truncate: 'end',
        maxWidthChars: 1,
        className: 'txt-smaller txt-subtext',
        label: server.city || server.country,
    });

    // Load bar
    const loadBar = Box({
        className: 'sidebar-vpn-loadbar-bg',
        children: [Box({
            className: 'sidebar-vpn-loadbar-fill',
            css: loadKnown
                ? `min-width: ${Math.max(2, server.load * 0.72)}rem; background-color: ${loadColor(server.load)};`
                : '',
        })],
    });

    const loadLabel = Label({
        hpack: 'end',
        vpack: 'center',
        className: 'txt-smaller txt-subtext',
        label: loadPct,
        css: loadKnown ? `color: ${loadColor(server.load)};` : '',
    });

    const fastestBadge = server.fastest ? Label({
        hpack: 'start',
        className: 'sidebar-vpn-fastest-badge txt-smaller',
        label: getString('Fastest'),
    }) : null;

    const serverInfo = Box({
        vertical: true,
        hexpand: true,
        children: [
            Box({
                children: [
                    nameLabel,
                    ...(fastestBadge ? [Box({ hexpand: false, css: 'min-width:0.4rem' }), fastestBadge] : []),
                ]
            }),
            cityLabel,
            loadBar,
        ],
    });

    const activeIcon = isActive ? MaterialIcon('check_circle', 'norm', {
        vpack: 'center',
        css: 'color: #5eba7d;',
    }) : null;

    const row = Button({
        className: `sidebar-vpn-server${isActive ? ' sidebar-vpn-server-active' : ''}`,
        tooltipText: isActive ? getString('Connected — click to disconnect') : getString('Click to connect'),
        onClicked: () => {
            if (isActive) {
                execAsync(['bash', '-c', `nmcli device disconnect proton0`]).catch(print);
            } else {
                // Disconnect any active proton connection first, then connect
                execAsync(['bash', '-c',
                    `nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="wireguard" && $1~/^ProtonVPN /{print $1}' | while read c; do nmcli connection down "$c"; done; nmcli connection up '${server.nm_name}'`
                ]).catch(print);
            }
        },
        child: Box({
            className: 'spacing-h-10',
            children: [
                leftIcon,
                serverInfo,
                loadLabel,
                ...(activeIcon ? [activeIcon] : []),
            ],
        }),
        setup: setupCursorHover,
    });

    return row;
};

export default (props) => {
    // State
    let vpnData = { active: '', servers: [] };

    const emptyContent = Box({
        homogeneous: true,
        children: [Box({
            vertical: true,
            vpack: 'center',
            className: 'txt spacing-v-10',
            children: [
                Box({
                    vertical: true,
                    className: 'spacing-v-5 txt-subtext',
                    children: [
                        MaterialIcon('vpn_lock', 'gigantic'),
                        Label({ label: getString('No ProtonVPN connections'), className: 'txt-small' }),
                    ]
                }),
            ]
        })]
    });

    const serverListBox = Box({
        vertical: true,
        className: 'spacing-v-5 sidebar-centermodules-scrollgradient-bottom-contentmargin',
    });

    const mainStack = Widget.Stack({
        children: {
            'empty': emptyContent,
            'list': Overlay({
                passThrough: true,
                child: Scrollable({
                    vexpand: true,
                    child: serverListBox,
                }),
                overlays: [Box({ className: 'sidebar-centermodules-scrollgradient-bottom' })],
            }),
        },
    });

    const refresh = () => {
        execAsync(['bash', VPN_STATUS_SCRIPT])
            .then((out) => {
                try {
                    vpnData = JSON.parse(out.trim());
                } catch { return; }
                const servers = vpnData.servers || [];
                if (servers.length === 0) {
                    mainStack.shown = 'empty';
                    return;
                }
                mainStack.shown = 'list';
                serverListBox.children = servers.map(s => VpnServerRow(s, vpnData.active));
            })
            .catch(print);
    };

    // Initial load + poll every 5s
    refresh();
    const pollId = setInterval(refresh, 5000);

    const bottomBar = Box({
        homogeneous: true,
        children: [Button({
            hpack: 'center',
            className: 'txt-small txt sidebar-centermodules-bottombar-button',
            label: getString('Open ProtonVPN'),
            onClicked: () => {
                execAsync(['bash', '-c', 'protonvpn-app &']).catch(print);
                closeEverything();
            },
            setup: setupCursorHover,
        })],
    });

    const widget = Box({
        ...props,
        className: 'spacing-v-10',
        vertical: true,
        children: [mainStack, bottomBar],
    });

    widget.connect('destroy', () => clearInterval(pollId));

    return widget;
};
