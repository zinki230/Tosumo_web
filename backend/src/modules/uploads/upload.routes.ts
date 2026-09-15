import { Router } from 'express';
import { authenticate } from '@shared/middleware/auth';
import { upload, processUploadResult } from '@shared/services/upload';
import { BadRequestError } from '@shared/utils/errors';
import { AuthenticatedRequest } from '@shared/types';
import { Response, NextFunction } from 'express';

const router = Router();

router.post('/', authenticate, (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  upload.single('file')(req, res, (err) => {
    if (err) {
      return next(new BadRequestError(err.message));
    }
    if (!req.file) {
      return next(new BadRequestError('No file provided'));
    }
    const result = processUploadResult(req.file);
    res.json({ success: true, data: result });
  });
});

router.post('/multiple', authenticate, (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  upload.array('files', 10)(req, res, (err) => {
    if (err) {
      return next(new BadRequestError(err.message));
    }
    if (!req.files || !Array.isArray(req.files)) {
      return next(new BadRequestError('No files provided'));
    }
    const results = req.files.map(processUploadResult);
    res.json({ success: true, data: results });
  });
});

export default router;
