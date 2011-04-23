import math, Image, ImageDraw, ImageFont

cell_size = 11
margin = 8
marker_width = marker_height = cell_size*8+margin*2

def create_image(text):

	image = Image.new("RGB", (marker_width, marker_height), (255, 255, 255))

	fontname = '/Users/atsusy/Library/Fonts/pixel4x4.ttf'
	font = ImageFont.truetype(fontname, int(cell_size / 12.0 * 72.0), encoding='unic')
	draw = ImageDraw.Draw(image)

	#frame
	draw.line([(0, int(cell_size/2)), (marker_width, int(cell_size/2))], width=cell_size, fill="#000000")
	draw.line([(int(cell_size/2), 0), (int(cell_size/2), marker_height)], width=cell_size, fill="#000000")
	draw.line([(marker_width-int(cell_size/2), 0), (marker_width-int(cell_size/2), marker_height)], width=cell_size, fill="#000000")
	draw.line([(0, marker_height-int(cell_size/2)), (marker_width, marker_height-int(cell_size/2))], width=cell_size, fill="#000000")

	#origin
	for y in range(cell_size+margin,(cell_size+margin+cell_size-1)):
		for x in range(cell_size+margin,(cell_size+margin+cell_size-1)):
			draw.point((x,y),fill="#000000")
			
	#contents
	sx = cell_size + margin + cell_size
	sy = cell_size + margin + cell_size
	
	sy -= 10

	draw.text((sx, sy), text, font=font, fill="#000000")

	return image

letters = u'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
image = Image.new("RGB", ((marker_width+margin*2)*10, (marker_height+margin*2)*(math.ceil(len(letters)/10.0))), (255, 255, 255))

for index in range(0, len(letters)):
	marker = create_image(letters[index])
	sx = (index % 10) * (marker_width+margin*2) + margin
	sy = (index / 10) * (marker_height+margin*2) + margin
	
	image.paste(marker, (sx, sy))

image.save("/Users/atsusy/Desktop/marker.png", "PNG")