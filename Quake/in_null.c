/*
Copyright (C) 1996-1997 Id Software, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/
// in_null.c -- for systems without a mouse

#include "quakedef.h"

void IN_Init (void)
{
}

void IN_Shutdown (void)
{
}

void IN_Commands (void)
{
}

void IN_Move (usercmd_t *cmd)
{
	extern float mouse_x, mouse_y;
	extern cvar_t sensitivity, m_yaw, m_pitch, m_forward, m_side;

	mouse_x *= sensitivity.value;
	mouse_y *= sensitivity.value;

	// Always apply mouse look on macOS (modern FPS standard)
	cl.viewangles[YAW] -= m_yaw.value * mouse_x;

	V_StopPitchDrift ();
	cl.viewangles[PITCH] += m_pitch.value * mouse_y;
	if (cl.viewangles[PITCH] > 80)
		cl.viewangles[PITCH] = 80;
	if (cl.viewangles[PITCH] < -70)
		cl.viewangles[PITCH] = -70;

	mouse_x = mouse_y = 0.0;
}

