import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  Logger,
} from '@nestjs/common';

interface HttpResponse {
  status(code: number): HttpResponse;
  json(body: { code: string; message: string }): void;
}

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<HttpResponse>();

    if (exception instanceof HttpException) {
      const body = exception.getResponse();
      if (typeof body === 'object' && body !== null &&
          'code' in body && typeof body.code === 'string' &&
          'message' in body && typeof body.message === 'string') {
        response.status(exception.getStatus()).json({
          code: body.code,
          message: body.message,
        });
        return;
      }

      response.status(exception.getStatus()).json({
        code: 'REQUEST_ERROR',
        message: exception.message,
      });
      return;
    }

    this.logger.error(exception);
    response.status(500).json({
      code: 'INTERNAL_ERROR',
      message: 'Something went wrong. Please try again.',
    });
  }
}
