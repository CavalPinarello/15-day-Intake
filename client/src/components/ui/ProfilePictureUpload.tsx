"use client";

import { useState, useRef } from "react";
import { useMutation } from "convex/react";
import { api } from "../../../convex/_generated/api";
import { Camera, Loader2 } from "lucide-react";
import { Avatar } from "./Avatar";
import { ImageCropModal } from "./ImageCropModal";

interface ProfilePictureUploadProps {
  currentImageUrl?: string | null;
  name: string;
  size?: "md" | "lg" | "xl";
  onUploadComplete?: (url: string) => void;
  entityType: "user" | "physician";
  entityId: string;
}

/**
 * Profile picture upload component with crop functionality.
 * Shows current avatar with edit overlay, opens crop modal on selection.
 */
export function ProfilePictureUpload({
  currentImageUrl,
  name,
  size = "lg",
  onUploadComplete,
  entityType,
  entityId,
}: ProfilePictureUploadProps) {
  const [isUploading, setIsUploading] = useState(false);
  const [selectedImage, setSelectedImage] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(currentImageUrl || null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const generateUploadUrl = useMutation(api.files.generateUploadUrl);
  const saveUserProfilePicture = useMutation(api.files.saveUserProfilePicture);
  const savePhysicianProfilePicture = useMutation(api.files.savePhysicianProfilePicture);

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate file type
    if (!file.type.startsWith("image/")) {
      alert("Please select an image file");
      return;
    }

    // Validate file size (max 10MB before crop)
    if (file.size > 10 * 1024 * 1024) {
      alert("Image must be smaller than 10MB");
      return;
    }

    // Create object URL for crop modal
    const imageUrl = URL.createObjectURL(file);
    setSelectedImage(imageUrl);

    // Reset file input
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  };

  const handleCropComplete = async (croppedBlob: Blob) => {
    setIsUploading(true);
    setSelectedImage(null);

    try {
      // Get upload URL from Convex
      const uploadUrl = await generateUploadUrl();

      // Upload the cropped image
      const response = await fetch(uploadUrl, {
        method: "POST",
        headers: {
          "Content-Type": croppedBlob.type,
        },
        body: croppedBlob,
      });

      if (!response.ok) {
        throw new Error("Upload failed");
      }

      const { storageId } = await response.json();

      // Save the profile picture reference
      let result;
      if (entityType === "user") {
        result = await saveUserProfilePicture({
          userId: entityId as any,
          storageId: storageId,
        });
      } else {
        result = await savePhysicianProfilePicture({
          physicianId: entityId as any,
          storageId: storageId,
        });
      }

      // Update preview
      if (result?.url) {
        setPreviewUrl(result.url);
        onUploadComplete?.(result.url);
      }
    } catch (error) {
      console.error("Error uploading profile picture:", error);
      alert("Failed to upload image. Please try again.");
    } finally {
      setIsUploading(false);
    }
  };

  const handleCropCancel = () => {
    if (selectedImage) {
      URL.revokeObjectURL(selectedImage);
    }
    setSelectedImage(null);
  };

  const sizeClasses = {
    md: "w-12 h-12",
    lg: "w-16 h-16",
    xl: "w-20 h-20",
  };

  return (
    <>
      <div className="relative inline-block">
        {/* Avatar with current image or initials */}
        <div className={`relative ${sizeClasses[size]}`}>
          <Avatar imageUrl={previewUrl} name={name} size={size} />

          {/* Loading overlay */}
          {isUploading && (
            <div className="absolute inset-0 bg-black/50 rounded-full flex items-center justify-center">
              <Loader2 className="w-6 h-6 text-white animate-spin" />
            </div>
          )}

          {/* Edit button overlay */}
          {!isUploading && (
            <button
              onClick={() => fileInputRef.current?.click()}
              className="absolute inset-0 bg-black/0 hover:bg-black/40 rounded-full flex items-center justify-center transition-all group"
            >
              <Camera className="w-5 h-5 text-white opacity-0 group-hover:opacity-100 transition-opacity" />
            </button>
          )}
        </div>

        {/* Hidden file input */}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleFileSelect}
          className="hidden"
          disabled={isUploading}
        />
      </div>

      {/* Crop Modal */}
      {selectedImage && (
        <ImageCropModal
          imageSrc={selectedImage}
          onCropComplete={handleCropComplete}
          onCancel={handleCropCancel}
        />
      )}
    </>
  );
}

export default ProfilePictureUpload;
