#ifndef MATH_UTILS_HEADER
#define MATH_UTILS_HEADER

/** Math utilities scrounged from parts of 2geom as well as some code found via Krugle -
 *  Game Boy Xport's mathutils.h .
 *
 * Copyright 2006 Michael G. Sloan <mgsloan@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it either under the terms of the GNU Lesser General Public
 * License version 2.1 as published by the Free Software Foundation
 * (the "LGPL") or, at your option, under the terms of the Mozilla
 * Public License Version 1.1 (the "MPL"). If you do not alter this
 * notice, a recipient may use your version of this file under either
 * the MPL or the LGPL.
 *
 * You should have received a copy of the LGPL along with this library
 * in the file COPYING-LGPL-2.1; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 * You should have received a copy of the MPL along with this library
 * in the file COPYING-MPL-1.1
 *
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY
 * OF ANY KIND, either express or implied. See the LGPL or the MPL for
 * the specific language governing rights and limitations.
 *
 */

#include <cmath>

const double Geom_EPSILON = 1e-18; // taken from libnr.  Probably sqrt(MIN_FLOAT).

/** Sign function - indicates the sign of a numeric type.  -1 indicates negative, 1 indicates
 *  positive, and 0 indicates, well, 0.  Mathsy people will know this is basically the derivative
 *  of abs, except for the fact that it is defined on 0.
 */
template <class T> inline int sgn(const T& x) {return (x < 0 ? -1 : (x > 0 ? 1 : 0) );}

/** Square function - sqr(x) is equivalent to x * x. */
template <class T> inline int sqr(const T& x) {return x * x;}

/** Cube function - cube(x) is equivalent to x * x * x. */
template <class T> inline int cube(const T& x) {return x * x * x;}

/** Between function - returns true if a number x is within a range. The values delimiting the
 *  range, as well as the number must have the same type.
 */
template <class T> inline const T& between (const T& min, const T& max, const T& x)
    { return min < x && max > x; }

/** Inverse Square-Root function - equivalent to 1 / sqrt(x), however much faster. Gleaned from the
 *  Quake 3 source, this function is very very magic in its working, actually converting a float to
 *  integer form and back during the process.
 */
inline float invSqrt (float x){
   float xhalf = 0.5f*x;
   int i = *(int*)&x;
   i = 0x5f3759df - (i>>1);
   x = *(float*)&i;
   x = x*(1.5f - xhalf*x*x);
   return x;
}

/** Returns x rounded to the nearest integer.  It is unspecified what happens
 *  if x is half way between two integers: we may in future use rint/round
 *  on platforms that have them.
 */
inline double round(double const x) { return std::floor(x + .5); }

/** Returns x rounded to the nearest \a places decimal places.

    Implemented in terms of round, i.e. we make no guarantees as to what happens if x is
    half way between two rounded numbers.
    
    Note: places is the number of decimal places without using scientific (e) notation, not the
    number of significant figures.  This function may not be suitable for values of x whose
    magnitude is so far from 1 that one would want to use scientific (e) notation.

    places may be negative: e.g. places = -2 means rounding to a multiple of .01
**/
inline double decimal_round(double const x, int const places) {
    //TODO: possibly implement with modulus instead?
    double const multiplier = std::pow(10.0, places);
    return round( x * multiplier ) / multiplier;
}

#endif
