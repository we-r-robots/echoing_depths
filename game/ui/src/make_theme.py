#!/usr/bin/env python3
"""Writes game/ui/theme.tres (the shared Echoing Depths Theme). Re-run after changing kit textures/colours."""
import os
HERE = os.path.dirname(os.path.abspath(__file__)); UI = os.path.dirname(HERE)
PAL = {}
for line in open(os.path.join(UI, '..', 'assets', 'palette', 'master.gpl')):
    p = line.split()
    if len(p) >= 4 and p[0].isdigit():
        PAL[p[3]] = tuple(int(v) for v in p[:3])
def col(n, a=1.0):
    r, g, b = PAL[n]; return f'Color({r/255:.4f}, {g/255:.4f}, {b/255:.4f}, {a})'

ext = []  # (type, path, id)
def E(t, path):
    i = f'{len(ext)+1}_{os.path.basename(path).split(".")[0]}'
    ext.append((t, path, i)); return f'ExtResource("{i}")'
SANS = E('FontFile', 'res://assets/fonts/depths_sans.fnt')
BOLD = E('FontFile', 'res://assets/fonts/depths_sans_bold.fnt')
SERIF = E('FontFile', 'res://assets/fonts/depths_serif.fnt')
subs = []
def SB(tex, m, content, draw_center=True):
    i = f'sb_{len(subs)+1}'
    t = E('Texture2D', f'res://ui/{tex}')
    ml, mt, mr, mb = m; cl, ct, cr, cb = content
    subs.append(f'''[sub_resource type="StyleBoxTexture" id="{i}"]
content_margin_left = {cl}.0
content_margin_top = {ct}.0
content_margin_right = {cr}.0
content_margin_bottom = {cb}.0
texture = {t}
texture_margin_left = {ml}.0
texture_margin_top = {mt}.0
texture_margin_right = {mr}.0
texture_margin_bottom = {mb}.0
draw_center = {"true" if draw_center else "false"}
''')
    return f'SubResource("{i}")'
def EMPTY():
    i = f'sb_{len(subs)+1}'
    subs.append(f'[sub_resource type="StyleBoxEmpty" id="{i}"]\n')
    return f'SubResource("{i}")'

panel = SB('panel.png', (6, 6, 6, 6), (8, 7, 8, 7))
panel_dim = SB('panel_dim.png', (6, 6, 6, 6), (8, 7, 8, 7))
panel_rare = SB('panel_rare.png', (6, 6, 6, 6), (8, 7, 8, 7))
b_n = SB('button_normal.png', (6, 6, 6, 6), (10, 4, 10, 5))
b_h = SB('button_hover.png', (6, 6, 6, 6), (10, 4, 10, 5))
b_p = SB('button_pressed.png', (6, 6, 6, 6), (10, 5, 10, 4))
b_d = SB('button_disabled.png', (6, 6, 6, 6), (10, 4, 10, 5))
focus = SB('focus.png', (6, 6, 6, 6), (0, 0, 0, 0), False)
c_n = SB('choice_normal.png', (8, 7, 8, 7), (8, 5, 8, 5))
c_h = SB('choice_hover.png', (8, 7, 8, 7), (8, 5, 8, 5))
c_p = SB('choice_pressed.png', (8, 7, 8, 7), (8, 5, 8, 5))
c_d = SB('choice_disabled.png', (8, 7, 8, 7), (8, 5, 8, 5))
r_n = SB('choice_rare.png', (8, 7, 8, 7), (8, 5, 8, 5))
r_h = SB('choice_rare_hover.png', (8, 7, 8, 7), (8, 5, 8, 5))
topbar = SB('topbar.png', (0, 1, 0, 3), (6, 2, 6, 4))
empty = EMPTY()

props = f'''default_font = {SANS}
default_font_size = 11
Label/colors/font_color = {col('ink9')}
Label/colors/font_shadow_color = {col('ink1')}
Label/constants/shadow_offset_x = 1
Label/constants/shadow_offset_y = 1
Label/constants/line_spacing = 0
Label/font_sizes/font_size = 11
Label/fonts/font = {SANS}
TitleLabel/base_type = &"Label"
TitleLabel/colors/font_color = {col('amber6')}
TitleLabel/colors/font_shadow_color = {col('ink1')}
TitleLabel/font_sizes/font_size = 16
TitleLabel/fonts/font = {SERIF}
HeaderLabel/base_type = &"Label"
HeaderLabel/colors/font_color = {col('ink10')}
HeaderLabel/font_sizes/font_size = 11
HeaderLabel/fonts/font = {BOLD}
TagLabel/base_type = &"Label"
TagLabel/colors/font_color = {col('crystal4')}
TagLabel/font_sizes/font_size = 11
TagLabel/fonts/font = {BOLD}
MutedLabel/base_type = &"Label"
MutedLabel/colors/font_color = {col('ink7')}
GoldLabel/base_type = &"Label"
GoldLabel/colors/font_color = {col('amber6')}
GoldLabel/font_sizes/font_size = 11
GoldLabel/fonts/font = {BOLD}
RichTextLabel/colors/default_color = {col('ink9')}
RichTextLabel/colors/font_shadow_color = {col('ink1')}
RichTextLabel/constants/shadow_offset_x = 1
RichTextLabel/constants/shadow_offset_y = 1
RichTextLabel/constants/line_separation = 1
RichTextLabel/font_sizes/normal_font_size = 11
RichTextLabel/font_sizes/bold_font_size = 11
RichTextLabel/fonts/normal_font = {SANS}
RichTextLabel/fonts/bold_font = {BOLD}
RichTextLabel/styles/normal = {empty}
RichTextLabel/styles/focus = {empty}
Button/colors/font_color = {col('amber6')}
Button/colors/font_hover_color = {col('amber7')}
Button/colors/font_pressed_color = {col('ink10')}
Button/colors/font_focus_color = {col('amber7')}
Button/colors/font_disabled_color = {col('fade2')}
Button/colors/font_outline_color = {col('ink1')}
Button/constants/outline_size = 0
Button/constants/h_separation = 4
Button/font_sizes/font_size = 11
Button/fonts/font = {BOLD}
Button/styles/normal = {b_n}
Button/styles/hover = {b_h}
Button/styles/pressed = {b_p}
Button/styles/disabled = {b_d}
Button/styles/focus = {focus}
ChoiceButton/base_type = &"Button"
ChoiceButton/styles/normal = {c_n}
ChoiceButton/styles/hover = {c_h}
ChoiceButton/styles/pressed = {c_p}
ChoiceButton/styles/disabled = {c_d}
ChoiceButton/styles/focus = {empty}
RareChoiceButton/base_type = &"Button"
RareChoiceButton/styles/normal = {r_n}
RareChoiceButton/styles/hover = {r_h}
RareChoiceButton/styles/pressed = {c_p}
RareChoiceButton/styles/disabled = {c_d}
RareChoiceButton/styles/focus = {empty}
PanelContainer/styles/panel = {panel}
Panel/styles/panel = {panel}
DimPanel/base_type = &"PanelContainer"
DimPanel/styles/panel = {panel_dim}
RarePanel/base_type = &"PanelContainer"
RarePanel/styles/panel = {panel_rare}
TopBar/base_type = &"PanelContainer"
TopBar/styles/panel = {topbar}
'''
out = [f'[gd_resource type="Theme" load_steps={len(ext)+len(subs)+1} format=3]', '']
for t, p, i in ext:
    out.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
out.append('')
out += subs
out.append('[resource]')
out.append(props)
open(os.path.join(UI, 'theme.tres'), 'w').write('\n'.join(out))
print('theme written')
