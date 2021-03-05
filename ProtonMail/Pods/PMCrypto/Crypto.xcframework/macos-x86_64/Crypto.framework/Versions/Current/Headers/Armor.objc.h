// Objective-C API for talking to github.com/ProtonMail/gopenpgp/v2/armor Go package.
//   gobind -lang=objc github.com/ProtonMail/gopenpgp/v2/armor
//
// File is generated by gobind. Do not edit.

#ifndef __Armor_H__
#define __Armor_H__

@import Foundation;
#include "ref.h"
#include "Universe.objc.h"

#include "Constants.objc.h"

/**
 * ArmorKey armors input as a public key.
 */
FOUNDATION_EXPORT NSString* _Nonnull ArmorArmorKey(NSData* _Nullable input, NSError* _Nullable* _Nullable error);

/**
 * ArmorWithType armors input with the given armorType.
 */
FOUNDATION_EXPORT NSString* _Nonnull ArmorArmorWithType(NSData* _Nullable input, NSString* _Nullable armorType, NSError* _Nullable* _Nullable error);

/**
 * ArmorWithTypeAndCustomHeaders armors input with the given armorType and
headers.
 */
FOUNDATION_EXPORT NSString* _Nonnull ArmorArmorWithTypeAndCustomHeaders(NSData* _Nullable input, NSString* _Nullable armorType, NSString* _Nullable version, NSString* _Nullable comment, NSError* _Nullable* _Nullable error);

// skipped function ArmorWithTypeBuffered with unsupported parameter or return types


/**
 * Unarmor unarmors an armored input into a byte array.
 */
FOUNDATION_EXPORT NSData* _Nullable ArmorUnarmor(NSString* _Nullable input, NSError* _Nullable* _Nullable error);

#endif