//
//  Project.h
//  GNISGeoCoder
//
//  Created by Dennis on 2/16/17.
///  The author disclaims copyright to this source code.
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely.
//
// Top-level include global file. Used inplace of the deprecated .pch file (bring that back Apple!)

#ifndef Project_h
#define Project_h

#ifdef DEBUG
#define NSLOG(x...) // NSLog(x)
#define DLOG(x...) NSLog(x)
#else
#define NSLOG(x...)
#define DLOG(...)
#endif

#endif /* Project_h */
